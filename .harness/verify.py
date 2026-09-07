#!/usr/bin/env python3
"""Portable harness checks. No installs, no network, no implicit app execution."""
import argparse
from collections import Counter
from datetime import date
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


def digest(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(root, relative):
    path = Path(relative)
    if path.is_absolute() or '..' in path.parts:
        raise ValueError('unsafe managed path: ' + str(relative))
    resolved = (root / path).resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise ValueError('path escapes repo: ' + str(relative))
    return resolved


def integrity(root):
    lock = json.loads((root / '.harness/lock.json').read_text())
    errors = []
    for name, expected in lock['files'].items():
        path = safe_path(root, name)
        if not path.is_file() or digest(path.read_bytes()) != expected:
            errors.append('generated drift: ' + name)
    config = json.loads((root / '.harness/project.json').read_text())
    for name in config.get('required_docs', []):
        if not safe_path(root, name).is_file():
            errors.append('missing policy/context: ' + name)
    return errors


def as_any_ratchet(root, cap):
    """Text-line ratchet, intentionally not an AST safety proof. Includes untracked TS."""
    files = subprocess.run(
        ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', 'src'],
        cwd=root, capture_output=True, check=True).stdout.decode().split('\0')
    count = 0
    for name in set(files):
        if not name.endswith(('.ts', '.tsx')) or name.startswith('src/shared/'):
            continue
        path = safe_path(root, name)
        if path.is_file():
            count += sum(bool(re.search(r'\bas\s+any\b', line))
                         for line in path.read_text().splitlines())
    head = subprocess.run(
        ['git', 'grep', '-I', '-n', '-E', r'(^|[^[:alnum:]_])as[[:space:]]+any([^[:alnum:]_]|$)', 'HEAD', '--',
         'src/**/*.ts', 'src/**/*.tsx', 'src/*.ts', 'src/*.tsx', ':(exclude)src/shared/**'],
        cwd=root, capture_output=True, text=True)
    if head.returncode not in (0, 1):
        return ['as-any HEAD baseline unavailable']
    baseline = min(cap, len(head.stdout.splitlines()))
    return [] if count <= baseline else [f'as-any lines {count} > baseline {baseline}']


def validate_events(path):
    errors, ids = [], set()
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
            required = ('id', 'learner', 'concept', 'date', 'repo', 'status', 'evidence')
            allowed = set(required) | {'reconstruction', 'transfer', 'supersedes'}
            if set(event) - allowed:
                raise ValueError('unknown event fields')
            if any(not isinstance(event.get(k), str) or not event[k].strip() for k in required):
                raise ValueError('required nonempty event fields')
            if any(not isinstance(v, str) or not v.strip() for v in event.values()):
                raise ValueError('event values must be nonempty strings')
            if event['id'] in ids:
                raise ValueError('duplicate event id')
            ids.add(event['id'])
            if event['status'] not in ('unverified', 'practicing', 'passed', 'mastered', 'regressed'):
                raise ValueError('invalid status')
            if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', event['date']):
                raise ValueError('date must be YYYY-MM-DD')
            date.fromisoformat(event['date'])
            if event['concept'].startswith('godot.cardgame.'):
                raise ValueError('card-game concepts belong in existing LEARNING_LEDGER')
            if event['status'] in ('passed', 'mastered') and not event.get('reconstruction'):
                raise ValueError('promotion requires reconstruction evidence')
            if event['status'] == 'mastered' and not event.get('transfer'):
                raise ValueError('mastery requires transfer evidence')
        except (ValueError, TypeError) as error:
            errors.append(f'learning event line {number}: {error}')
    return errors


def diagnostics(kind, output, root):
    """Normalize diagnostic identity, retaining multiplicity and message details."""
    if kind == 'eslint-json':
        records = json.loads(output)
        return Counter(
            str(Path(record['filePath']).relative_to(root)) + ': ' +
            str(message.get('ruleId')) + ': ' + str(message['severity']) + ': ' + message['message']
            for record in records for message in record['messages'])
    if kind == 'tsc':
        groups = []
        for line in output.splitlines():
            match = re.match(r'^(.*?)\(\d+,\d+\): (error TS\d+: .*)$', line)
            if match:
                groups.append(match[1] + ': ' + match[2])
            elif line.startswith('error TS'):
                groups.append(line)
            elif line.startswith(' ') and groups:
                groups[-1] += '\n' + line
        return Counter(item.replace(str(root), '<repo>') for item in groups)
    raise ValueError('unsupported diagnostic format: ' + str(kind))


def baseline_allows(root, check, output):
    baseline = json.loads(safe_path(root, check['baseline']).read_text())
    known = Counter(baseline['checks'][check['id']])
    current = diagnostics(check['diagnostic_format'], output, root)
    # Unparseable/crashing tools must never become a green gate.
    return bool(current) and not (current - known)


def run_checks(root, config, only=None, gate=False):
    failures = []
    selected = [c for c in config.get('checks', []) if only is None or c['id'] in only]
    if only is not None and set(only) - {c['id'] for c in selected}:
        return ['unknown check requested']
    for check in selected:
        if check.get('manual'):
            failures.append(check['id'] + ': NOT RUN (manual: ' + check['manual'] + ')')
            continue
        argv = check['argv']
        cwd = safe_path(root, check.get('cwd', '.'))
        executable = argv[0]
        if ('/' in executable and not (cwd / executable).is_file()) or (
                '/' not in executable and not shutil.which(executable)):
            failures.append(check['id'] + ': NOT RUN (tool unavailable)')
            continue
        print('RUN ' + check['id'] + ': ' + json.dumps(argv), flush=True)
        try:
            result = subprocess.run(argv, cwd=cwd, timeout=check.get('timeout', 120),
                                    capture_output=True, text=True)
            print(result.stdout, end='')
            print(result.stderr, end='', file=sys.stderr)
            if result.returncode:
                if (gate and check.get('baseline') and result.returncode in check.get('diagnostic_exit_codes', [1, 2])
                        and not result.stderr.strip() and baseline_allows(root, check, result.stdout)):
                    print(check['id'] + ': BASELINE DEBT (application FAIL; no new diagnostics)')
                else:
                    failures.append(f"{check['id']}: FAIL ({result.returncode})")
        except (OSError, subprocess.TimeoutExpired) as error:
            failures.append(check['id'] + ': FAIL (' + str(error) + ')')
    return failures


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--only', action='append')
    parser.add_argument('--ratchet', action='store_true')
    parser.add_argument('--gate', action='store_true', help='Allow only explicitly recorded pre-existing diagnostics; --run required')
    args = parser.parse_args(argv)
    root = args.root.resolve()
    config = json.loads((root / '.harness/project.json').read_text())
    if args.list:
        print(json.dumps(config.get('checks', []), ensure_ascii=False, indent=2))
        return 0
    errors = integrity(root)
    events = root / 'docs/learning/events.jsonl'
    if events.is_file():
        errors.extend(validate_events(events))
    if args.ratchet and 'as_any_cap' in config:
        errors.extend(as_any_ratchet(root, config['as_any_cap']))
    if args.run:
        errors.extend(run_checks(root, config, args.only, args.gate))
    elif args.only:
        errors.append('--only requires --run')
    if args.gate and not args.run:
        errors.append('--gate requires --run')
    for error in errors:
        print(error, file=sys.stderr)
    if not errors:
        print('PASS harness integrity' + (' and selected regression gates; see raw application status above' if args.gate
              else ' and selected checks' if args.run else '; application checks NOT RUN'))
    return 1 if errors else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print('Harness check failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
