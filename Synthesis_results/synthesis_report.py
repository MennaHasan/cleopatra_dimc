#!/usr/bin/env python3
"""Parse Synopsys area/timing reports into PNG plots and summary tables only.

Run: python3 Synthesis_results/synthesis_report.py [report_directory] [--frequency 1G]
Requires Python 3.9+ and matplotlib. Area defaults to µm²; time units come from the units report.
"""
import argparse
import textwrap

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import re
from collections import defaultdict
from pathlib import Path

NUMBER = r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?'
COLORS = ['#2563eb', '#0d9488', '#7c3aed', '#ea580c', '#db2777', '#0891b2', '#64748b', '#65a30d']


def component(instance):
    """Classify local logic by its owning hierarchy, most specific owner first."""
    parts = instance.lower().split('/')
    if any('fifo' in p for p in parts):
        return 'FIFOs'
    if any(p in ('i_ctrl', 'i_controller', 'u_controller') for p in parts):
        return 'Controller'
    if any('streamer' in p for p in parts):
        return 'Streamers'
    if any('memory_mux' in p for p in parts):
        return 'Memory muxes'
    if any('accumulator' in p for p in parts):
        return 'Accumulators'
    if any('datapath' in p for p in parts):
        return 'Other datapath logic'
    return 'Other / wrapper logic'


def parse_area(text):
    def summary(label):
        match = re.search(r'^\s*' + re.escape(label) + r':\s*(' + NUMBER + r')\s*$', text, re.M)
        if not match:
            raise ValueError(f'Missing numeric area field: {label}')
        return float(match[1])

    total = summary('Total cell area')
    if total <= 0:
        raise ValueError('Total cell area must be positive')
    row_re = re.compile(r'^\s*(\S+)\s+' + r'\s+'.join([f'({NUMBER})'] * 5) + r'(?:\s+(\S+))?\s*$')
    rows = []
    hierarchy = text.partition('Hierarchical area distribution')[2]
    for line in hierarchy.splitlines():
        match = row_re.match(line)
        if not match:
            continue
        name, absolute, percent, comb, seq, macro, design = match.groups()
        rows.append(dict(instance=name, global_area=float(absolute), reported_percent=float(percent),
                         combinational=float(comb), sequential=float(seq), macros=float(macro),
                         design=design or '', component=component(name)))
    if not rows:
        raise ValueError('No hierarchical area rows found')
    # Global areas include descendants. Only local columns can be added safely.
    groups = defaultdict(float)
    macro_rows = []
    for row in rows:
        groups[row['component']] += row['combinational'] + row['sequential']
        groups['Macros'] += row['macros']
        if row['macros']:
            macro_rows.append(dict(instance=row['instance'], area=row['macros'], percent=100 * row['macros'] / total))
    types = {'Combinational': summary('Combinational area'),
             'Sequential': summary('Noncombinational area'), 'Macros': summary('Macro/Black Box area')}
    tolerance = max(0.001, len(rows) * 0.00015)
    for key, column in [('Combinational', 'combinational'), ('Sequential', 'sequential'), ('Macros', 'macros')]:
        if abs(sum(r[column] for r in rows) - types[key]) > tolerance:
            raise ValueError(f'Incomplete hierarchy: local {key} areas do not match summary')
    if abs(sum(types.values()) - total) > tolerance:
        raise ValueError('Cell type areas do not sum to total cell area')
    physical = re.search(r'^\s*Total area:\s*(' + NUMBER + r')\s*$', text, re.M)
    return dict(total=total, reported_total_area=float(physical[1]) if physical else None, macros=types['Macros'], macro_percent=100 * types['Macros'] / total,
                types=types, components=dict(sorted(((k, v) for k, v in groups.items() if v > 0),
                                                   key=lambda pair: -pair[1])),
                hierarchy=rows, macro_instances=macro_rows,
                buffer_inverter_area=summary('Buf/Inv area'))



def parse_units(text):
    """Read explicit unit labels without assuming an unreported area unit."""
    units = {}
    for kind in ('time', 'area'):
        match = re.search(r'^\s*' + kind + r'_unit\s*:\s*(.+)$', text, re.M | re.I)
        if match and match[1].strip().upper() != 'N/A':
            value = match[1].strip()
            symbol = re.search(r'\(([^)]+)\)', value)
            units[kind] = symbol[1] if symbol else value
    return units


def resolve_units(folder, files):
    """Prefer units sharing a report prefix; otherwise use a sole units report."""
    matches = set()
    for kind, path in files.items():
        prefix = re.split(r'(?:^|_)' + kind + '_', path.stem, flags=re.I)[0]
        candidate = folder / f'{prefix + "_" if prefix else ""}units.rpt'
        if candidate.is_file():
            matches.add(candidate)
    if not matches:
        matches = set(folder.glob('*units*.rpt'))
    if len(matches) > 1:
        raise ValueError('Multiple possible units reports; use matching prefixes such as 11_units.rpt')
    if not matches:
        return {}, None
    path = matches.pop()
    return parse_units(path.read_text(errors='replace')), path.name


def parse_timing(text):
    paths = []
    for index, block in enumerate(re.split(r'^\s*Startpoint:\s*', text, flags=re.M)[1:], 1):
        def field(label):
            match = re.search(r'^\s*' + re.escape(label) + r':\s*(.+)$', block, re.M)
            if not match:
                raise ValueError(f'Path {index}: missing {label}')
            return match[1].strip()

        def time_value(label):
            values = re.findall(r'^\s*' + label + r'\s+(' + NUMBER + r')\s*$', block, re.M)
            if not values:
                raise ValueError(f'Path {index}: missing {label}')
            # The second arrival line is negated in the slack subtraction.
            return float(values[0])

        slack = re.search(r'^\s*slack\s*\(([^)]+)\)\s+(' + NUMBER + r')\s*$', block, re.M)
        if not slack:
            raise ValueError(f'Path {index}: missing slack/status')
        start = block.splitlines()[0].strip()
        endpoint = field('Endpoint')
        paths.append(dict(path=index, startpoint=re.split(r'\s+\(', start)[0],
                          endpoint=re.split(r'\s+\(', endpoint)[0], path_group=field('Path Group'),
                          path_type=field('Path Type'), data_required_time=time_value('data required time'),
                          data_arrival_time=time_value('data arrival time'), slack=float(slack[2]),
                          status=slack[1].strip()))
    if not paths:
        raise ValueError('No timing paths found')
    return paths


def save_figure(fig, path):
    fig.savefig(path, dpi=200, facecolor='white', bbox_inches='tight')
    plt.close(fig)


def area_chart(groups, total, title, unit, output):
    fig, (ax, detail) = plt.subplots(1, 2, figsize=(14, 6), gridspec_kw={'width_ratios': [1, 1.5]})
    names, values = list(groups), list(groups.values())
    colors = [COLORS[i % len(COLORS)] for i in range(len(names))]
    ax.pie(values, colors=colors, startangle=90, counterclock=False,
           wedgeprops={'width': 0.30, 'edgecolor': 'white', 'linewidth': 1})
    ax.text(0, 0.07, f'{total:,.2f}', ha='center', fontsize=17, weight='bold')
    ax.text(0, -0.12, f'Total cell area ({unit})', ha='center', fontsize=10, color='#526079')
    detail.axis('off')
    for i, (name, value) in enumerate(groups.items()):
        y = 0.91 - i * 0.10
        detail.add_patch(plt.Rectangle((0.01, y - 0.025), 0.025, 0.04,
                                      color=colors[i], transform=detail.transAxes))
        detail.text(0.06, y, name, transform=detail.transAxes, va='center', fontsize=11)
        detail.text(0.98, y, f'{value:,.4f} {unit}  |  {value / total:.2%}',
                    transform=detail.transAxes, va='center', ha='right', fontsize=10)
    fig.suptitle(title, fontsize=20, weight='bold')
    fig.subplots_adjust(top=0.86, bottom=0.06, wspace=0.08)
    save_figure(fig, output)


def text_table(title, headers, rows, output, widths=None, note=''):
    wrapped = [[textwrap.fill(str(value), width=(widths or [40] * len(headers))[i],
                              break_long_words=True, break_on_hyphens=False)
                for i, value in enumerate(row)] for row in rows]
    heights = [max(cell.count('\n') + 1 for cell in row) for row in wrapped]
    height = max(3.5, 1.8 + sum(max(0.48, h * 0.24) for h in heights))
    fig, ax = plt.subplots(figsize=(14, height))
    ax.axis('off')
    tab = ax.table(cellText=wrapped, colLabels=headers, loc='center', cellLoc='left', colLoc='left',
                   colWidths=[w / sum(widths) for w in widths] if widths else None)
    tab.auto_set_font_size(False)
    tab.set_fontsize(10)
    for (r, c), cell in tab.get_celld().items():
        cell.set_edgecolor('#e2e8f0')
        cell.PAD = 0.05
        if r == 0:
            cell.set_facecolor('#172033')
            cell.set_text_props(color='white', weight='bold')
            cell.set_height(0.45 / height)
        else:
            cell.set_facecolor('#f1f5f9' if r % 2 else 'white')
            cell.set_height(max(0.48, heights[r - 1] * 0.24) / height)
    ax.set_title(title, fontsize=20, weight='bold', pad=22)
    if note:
        fig.text(0.5, 0.025, note, fontsize=10, color='#526079', ha='center', wrap=True)
    fig.subplots_adjust(top=0.86, bottom=0.13)
    save_figure(fig, output)


def timing_chart(paths, unit, output, frequency):
    frequency = frequency if frequency.lower().endswith('hz') else frequency + 'Hz'
    fig, axes = plt.subplots(len(paths), 1, figsize=(13, max(3.5, 3 * len(paths))), squeeze=False)
    for path, ax in zip(paths, axes[:, 0]):
        values = [path['data_arrival_time'], path['data_required_time']]
        ax.barh(['Arrival', 'Required'], values, color=['#2563eb', '#0d9488'], height=0.5)
        ax.invert_yaxis()
        low, high = min(0, *values), max(0, *values)
        span = high - low or 1
        ax.set_xlim(low - span * 0.03, high + span * 0.25)
        for i, value in enumerate(values):
            ax.text(value + span * 0.015, i, f'{value:.4f} {unit}', va='center', fontsize=11)
        ax.set_title(f"Path {path['path']} | {path['path_group']} | {path['path_type']} | "
                     f"Slack {path['slack']:.4f} {unit} ({path['status']})", loc='left', fontsize=12)
        ax.set_xlabel(f'Time ({unit}) — independent scale for each path')
        for side in ['top', 'right']:
            ax.spines[side].set_visible(False)
        ax.grid(axis='x', alpha=0.15)
        ax.set_axisbelow(True)
    fig.suptitle(f'Timing summary · {frequency}', fontsize=20, weight='bold')
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    save_figure(fig, output)


def generate(output, frequency, area, paths, sources, area_unit, time_unit):
    """Write only PNGs; include all requested timing fields in path detail images."""
    frequency = frequency if frequency.lower().endswith('hz') else frequency + 'Hz'
    output.mkdir(parents=True, exist_ok=True)
    area_chart(area['components'], area['total'], f'Area by component · {frequency}', area_unit,
               output / 'area_components.png')
    area_chart(area['types'], area['total'], f'Area by cell type · {frequency}', area_unit,
               output / 'area_cell_types.png')
    area_chart({'Macros': area['macros'], 'Other cells': area['total'] - area['macros']},
               area['total'], f'Macro share of total cell area · {frequency}', area_unit,
               output / 'area_macros.png')
    physical = (f"{area['reported_total_area']:,.6f} {area_unit}"
                if area['reported_total_area'] is not None else 'undefined in source report')
    summary = [['Total cell area', f"{area['total']:,.6f} {area_unit}"],
               ['Reported total area', physical],
               ['Combinational area', f"{area['types']['Combinational']:,.6f} {area_unit}"],
               ['Sequential area', f"{area['types']['Sequential']:,.6f} {area_unit}"],
               ['Macro / black box area', f"{area['macros']:,.6f} {area_unit}"],
               ['Macros / total cell area', f"{area['macro_percent']:.2f}%"],
               ['Buffer / inverter area (included in combinational)', f"{area['buffer_inverter_area']:,.6f} {area_unit}"]]
    text_table(f'Area summary · {frequency}', ['Quantity', 'Value'], summary,
               output / 'area_summary.png', [60, 55])
    timing_chart(paths, time_unit, output / 'timing.png', frequency)
    # Remove stale detail pages only after rendering the new input summary successfully.
    for old in output.glob('timing_path_*.png'):
        if re.fullmatch(r'timing_path_\d+\.png', old.name):
            old.unlink()
    for path in paths:
        rows = [['Startpoint', path['startpoint']], ['Endpoint', path['endpoint']],
                ['Path group', path['path_group']], ['Path type', path['path_type']],
                ['Data required time', f"{path['data_required_time']:.4f} {time_unit}"],
                ['Data arrival time', f"{path['data_arrival_time']:.4f} {time_unit}"],
                ['Slack', f"{path['slack']:.4f} {time_unit}"], ['Status', path['status']]]
        text_table(f"Timing path {path['path']} · {frequency}", ['Field', 'Value'], rows,
                   output / f"timing_path_{path['path']:03d}.png", [25, 105])



def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input_dir', nargs='?', type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument('--output-dir', type=Path, help='Parent for <frequency> output folders (default: input folder)')
    parser.add_argument('--frequency', help='Only process this filename frequency, e.g. 1G')
    parser.add_argument('--area-unit', help='Display label, e.g. µm²; does not convert values')
    parser.add_argument('--time-unit', help='Display label, e.g. ns; does not convert values')
    args = parser.parse_args(argv)
    reports = defaultdict(dict)
    pattern = re.compile(r'(?:^|_)(area|timing)_(.+)\.rpt$', re.I)
    if not args.input_dir.is_dir():
        parser.error(f'Input directory does not exist: {args.input_dir}')
    for path in sorted(args.input_dir.glob('*.rpt')):
        match = pattern.search(path.name)
        if not match:
            continue
        kind, frequency = match[1].lower(), match[2]
        if args.frequency and frequency != args.frequency:
            continue
        if not re.fullmatch(r'[\w][\w.\-]*', frequency):
            parser.error(f'Unsafe frequency suffix: {frequency!r}')
        if kind in reports[frequency]:
            parser.error(f'Duplicate {kind} reports for {frequency}: {reports[frequency][kind].name}, {path.name}')
        reports[frequency][kind] = path
    if not reports:
        parser.error('No matching area_<frequency>.rpt / timing_<frequency>.rpt reports found')
    # Validate every pair before producing outputs.
    parsed = []
    for frequency, files in reports.items():
        if set(files) != {'area', 'timing'}:
            parser.error(f'{frequency}: need both area and timing reports')
        try:
            area = parse_area(files['area'].read_text(errors='replace'))
            paths = parse_timing(files['timing'].read_text(errors='replace'))
            units, units_source = resolve_units(args.input_dir, files)
        except ValueError as exc:
            parser.error(f'{frequency}: {exc}')
        parsed.append((frequency, files, area, paths, units, units_source))
    for frequency, files, area, paths, units, units_source in parsed:
        output = (args.output_dir or args.input_dir) / frequency
        sources = {k: p.name for k, p in files.items()}
        sources['units'] = units_source
        generate(output, frequency, area, paths, sources,
                 args.area_unit or units.get('area', 'µm²'),
                 args.time_unit or units.get('time', 'report time units'))
        print(f"{frequency}: area {area['total']:,.4f}; macros {area['macro_percent']:.2f}%; {len(paths)} timing paths")
        print(f'  PNG outputs: {output}')


if __name__ == '__main__':
    main()
