#!/usr/bin/env python3
"""Claude stdin event adapter. Direct file guards are not a shell sandbox."""
import json
from pathlib import Path
import re
import subprocess
import sys

sys.dont_write_bytecode = True
from verify import integrity, safe_path, as_any_ratchet


def context(event, message):
    return {'hookSpecificOutput': {'hookEventName': event, 'additionalContext': message}}


def handle(payload, root):
    event = payload.get('hook_event_name')
    config = json.loads((root / '.harness/project.json').read_text())
    tool = payload.get('tool_name', '')
    inputs = payload.get('tool_input') or {}
    raw = inputs.get('file_path', '')
    if event == 'PreToolUse' and tool in ('Read', 'Edit', 'Write', 'MultiEdit'):
        if not isinstance(raw, str) or not raw:
            return None
        path = Path(raw.replace('\\', '/'))
        if not path.is_absolute():
            path = Path(payload.get('cwd', str(root))) / path
        path = path.resolve()
        secret = any(p == '.env' or p.startswith('.env.') for p in path.parts)
        godot = config.get('godot', False)
        protected = godot and tool != 'Read' and (
            path.suffix in ('.uid', '.import') or '.godot' in path.parts)
        if secret or protected:
            return {'hookSpecificOutput': {
                'hookEventName': event, 'permissionDecision': 'deny',
                'permissionDecisionReason': 'Mentor policy: protected metadata or secret; use the approved editor/configuration workflow.'}}
        # .gd/.tscn ask lives in permissions, so existing runtime approval is not re-asked here.
    if event == 'UserPromptSubmit':
        prompt = payload.get('prompt', '')
        hints = []
        if re.search(r'還債|考我|教我|學習|learning', prompt, re.I):
            hints.append('學習證據索引：.harness/learning-sources.json；一次一個概念。')
        if re.search(r'bug|修|錯誤|決策|regression|review', prompt, re.I):
            hints.extend('相關脈絡：' + p for p in config.get('context_docs', [])
                         if safe_path(root, p).is_file())
        if hints:
            return context(event, '\n'.join(hints[:4]))
    if event == 'PostToolUse' and tool in ('Edit', 'Write', 'MultiEdit') and raw:
        suffix = Path(raw).suffix
        if suffix in ('.ts', '.tsx', '.js', '.jsx', '.gd', '.tscn', '.py'):
            return context(event, '依 .harness/project.json 選對應驗證；python3 .harness/verify.py --list。未執行不得稱通過。')
    if event == 'Stop':
        errors = integrity(root)
        if 'as_any_cap' in config:
            errors.extend(as_any_ratchet(root, config['as_any_cap']))
        for check in config.get('stop_checks', []):
            result = subprocess.run(
                [sys.executable, str(root / '.harness/verify.py'), '--run', '--gate', '--only', check],
                cwd=root, capture_output=True, text=True, timeout=150)
            if result.returncode:
                # Avoid forwarding app output that may contain secret values.
                errors.append(check + ': FAIL/NOT RUN; run the listed check to inspect diagnostics')
        if errors and not payload.get('stop_hook_active'):
            return {'decision': 'block', 'reason': '\n'.join(errors)}
        if errors:
            print('Mentor gate remains FAIL; recursion stopped, report the unresolved checks.', file=sys.stderr)
    return None


def main():
    root = Path(__file__).resolve().parents[1]
    try:
        payload = json.load(sys.stdin)
        if not isinstance(payload, dict):
            raise ValueError('event must be an object')
        result = handle(payload, root)
        if result:
            print(json.dumps(result, ensure_ascii=False))
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print('Mentor hook error: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
