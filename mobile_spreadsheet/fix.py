import os

replacements = {
    'â”€': '─',
    'â–¼': '▼',
    'â °': '⏰',
    'â€¦': '…',
    'â• ': '═',
    'â†’': '→',
    'ðŸ“…': '📅',
    'âœ“': '✓',
    'âœ—': '✗',
    'âœ”': '✔',
    'âœ˜': '✘',
}

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    original = content
    for k, v in replacements.items():
        content = content.replace(k, v)
        
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Fixed {filepath}')

base_dir = 'd:/abuzer projects/Table sheets project/mobile_spreadsheet/lib'
for root, dirs, files in os.walk(base_dir):
    for f in files:
        if f.endswith('.dart'):
            fix_file(os.path.join(root, f))
