import re
from pathlib import Path
from collections import OrderedDict

def parse_tres(path):
    text = path.read_text(encoding='utf-8')
    data = OrderedDict()
    data['rounds'] = []
    
    # Map ext_resource IDs to paths
    ext_resources = {}
    for line in re.findall(r'\[ext_resource[^\]]+\]', text):
        id_match = re.search(r'\bid="([^"]+)"', line)
        path_match = re.search(r'path="([^"]+)"', line)
        if id_match and path_match:
            ext_resources[id_match.group(1)] = path_match.group(1)
    
    # Extract channel-level properties
    channel_props = re.findall(r'^([a-z_]+) = (.+)$', text, re.MULTILINE)
    for k, v in channel_props:
        if k == 'script':
            continue
        data[k] = v.strip()
    
    # Extract round sub-resources
    round_blocks = re.findall(r'\[sub_resource type="Resource" id="round_(\d+)"\](.+?)(?=\n\[sub_resource|\n\[resource\])', text, re.DOTALL)
    for num, block in round_blocks:
        rd = OrderedDict()
        rd['round_number'] = num
        for k, v in re.findall(r'^([a-z_]+) = (.+)$', block, re.MULTILINE):
            if k == 'script':
                continue
            rd[k] = v.strip()
        data['rounds'].append(rd)
    
    # Resolve shader name
    shader_val = data.get('background_shader', '')
    shader_name = '-'
    if 'ExtResource(' in shader_val:
        m = re.search(r'ExtResource\("([^"]+)"\)', shader_val)
        if m:
            ext_id = m.group(1)
            shader_path = ext_resources.get(ext_id, '')
            shader_name = shader_path.split('/')[-1].replace('.gdshader', '') if shader_path else ext_id
    data['_shader_name'] = shader_name
    
    return data

def fmt(v):
    v = v.replace('Vector2i(', '').replace(')', '')
    v = v.replace('Color(', '').replace(')', '')
    return v

def bonus_str(bonus_dict_str):
    m = re.findall(r'"(\w+)":\s*([\d.]+)', bonus_dict_str)
    parts = []
    for k, v in m:
        parts.append(f"{k}={v}")
    return ", ".join(parts)

def strip_quotes(v):
    if v.startswith('"') and v.endswith('"'):
        return v[1:-1]
    return v

output = []
output.append("# Channel Difficulty Data Reference")
output.append("")
output.append("Auto-generated from `Resources/Data/Channels/channel_*.tres`.")
output.append("")

# Summary table
output.append("## Quick Reference")
output.append("")
output.append("| Ch | Name | Unlock | Goal× | Yahtzee× | Shop× | Dice× | Reroll× | Goof× | Debuff× | Carryover |")
output.append("|----|------|--------|-------|----------|-------|-------|---------|-------|---------|-----------|")

channels = []
for p in sorted(Path('Resources/Data/Channels').glob('channel_*.tres')):
    d = parse_tres(p)
    channels.append(d)
    ch = d.get('channel_number', '?')
    name = strip_quotes(d.get('display_name', '')).replace('Channel ', 'Ch')
    unlock = d.get('unlock_requirement', '0')
    goal = d.get('goal_score_multiplier', '1.0')
    yaht = d.get('yahtzee_bonus_multiplier', '1.0')
    shop = d.get('shop_price_multiplier', '1.0')
    dice = d.get('colored_dice_cost_multiplier', '1.0')
    reroll = d.get('reroll_base_cost_multiplier', '1.0')
    goof = d.get('goof_off_multiplier', '1.0')
    debuff = d.get('debuff_intensity_multiplier', '1.0')
    carry = d.get('allowed_carryover_count', '-')
    output.append(f"| {ch} | {name} | {unlock} | {goal} | {yaht} | {shop} | {dice} | {reroll} | {goof} | {debuff} | {carry} |")

output.append("")

# Detailed sections
for d in channels:
    ch = d.get('channel_number', '?')
    name = strip_quotes(d.get('display_name', 'Unknown'))
    desc = strip_quotes(d.get('description', ''))
    unlock = d.get('unlock_requirement', '0')
    
    output.append(f"## Channel {ch} — {name}")
    output.append("")
    output.append(f"**Description:** {desc}")
    output.append("")
    output.append(f"**Unlock Requirement:** {unlock}")
    output.append("")
    
    # Round table
    output.append("### Round Configuration")
    output.append("")
    output.append("| Rd | Challenge Diff | Max Debuffs | Debuff Cap | Target Score | Reward $ | Bonus Multipliers |")
    output.append("|----|----------------|-------------|------------|--------------|----------|-------------------|")
    for r in d['rounds']:
        rd_num = r.get('round_number', '?')
        diff = fmt(r.get('challenge_difficulty_range', '-'))
        max_d = r.get('max_debuffs', '-')
        cap = r.get('debuff_difficulty_cap', '-')
        tgt = r.get('target_score_override', '-')
        if tgt == '-1' or tgt == '0' or tgt == '-':
            tgt = 'Default'
        rew = fmt(r.get('reward_money_override', '-'))
        if rew == '0':
            rew = 'Default'
        bonus = bonus_str(r.get('bonus_multipliers', '{}'))
        output.append(f"| {rd_num} | {diff} | {max_d} | {cap} | {tgt} | {rew} | {bonus} |")
    output.append("")
    
    # Multipliers
    output.append("### Channel Multipliers")
    output.append("")
    output.append(f"- **Goal Score:** {d.get('goal_score_multiplier', '1.0')}")
    output.append(f"- **Yahtzee Bonus:** {d.get('yahtzee_bonus_multiplier', '1.0')}")
    output.append(f"- **Shop Prices:** {d.get('shop_price_multiplier', '1.0')}")
    output.append(f"- **Colored Dice Cost:** {d.get('colored_dice_cost_multiplier', '1.0')}")
    output.append(f"- **Reroll Base Cost:** {d.get('reroll_base_cost_multiplier', '1.0')}")
    output.append(f"- **Goof-Off:** {d.get('goof_off_multiplier', '1.0')}")
    output.append(f"- **Debuff Intensity:** {d.get('debuff_intensity_multiplier', '1.0')}")
    output.append("")
    
    # Carryover
    carry_count = d.get('allowed_carryover_count', None)
    carry_types = d.get('allowed_carryover_types', None)
    if carry_count is not None:
        item_word = "item" if carry_count == "1" else "items"
        output.append(f"**Carryover:** {carry_count} {item_word}")
        if carry_types:
            types = carry_types.replace('Array[String]([', '').replace('])', '').replace('"', '').replace(', ', ', ')
            output.append(f"- Types: {types}")
        output.append("")
    
    # Special rules / forced challenges / disabled items
    force = d.get('force_specific_challenges', '[]')
    disabled = d.get('disabled_shop_items', '[]')
    rules = d.get('special_rules', '{}')
    
    has_extras = False
    if force and force != 'Array[String]([])' and force != '[]':
        output.append(f"**Forced Challenges:** {force}")
        has_extras = True
    if disabled and disabled != 'Array[String]([])' and disabled != '[]':
        output.append(f"**Disabled Shop Items:** {disabled}")
        has_extras = True
    if rules and rules != '{}' and rules != '{\n}':
        output.append(f"**Special Rules:** {rules}")
        has_extras = True
    if has_extras:
        output.append("")
    
    # Shader
    shader_name = d.get('_shader_name', '-')
    output.append(f"**Background Shader:** `{shader_name}`")
    output.append("")
    output.append("---")
    output.append("")

Path('CHANNELS_REFERENCE.md').write_text('\n'.join(output), encoding='utf-8')
print("Written CHANNELS_REFERENCE.md")
