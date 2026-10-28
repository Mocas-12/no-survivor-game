"""Build an OFL UI subset from the project's actual bilingual strings."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset

root = Path(__file__).resolve().parents[1]
font = TTFont(root / '.local-tools/NotoSansSC-original.ttf')
instantiateVariableFont(font, {'wght': 500}, inplace=True)
text = ''.join(chr(i) for i in range(32,127))
for folder, pattern in [('scripts','*.gd'),('scenes','*.tscn')]:
    text += ''.join(p.read_text(encoding='utf-8-sig') for p in (root/folder).glob(pattern))
options = subset.Options()
options.name_IDs = ['*']
subsetter = subset.Subsetter(options=options)
subsetter.populate(text=text)
subsetter.subset(font)
for record in font['name'].names:
    replacements = {1:'No Survivor UI',2:'Regular',3:'NoSurvivorUI-500-Subset',4:'No Survivor UI Regular',6:'NoSurvivorUI-Regular',16:'No Survivor UI',17:'Regular'}
    if record.nameID in replacements:
        record.string = replacements[record.nameID].encode(record.getEncoding(), errors='replace')
destination = root/'assets/fonts/NoSurvivorUI.ttf'
font.save(destination)
print(destination.name,destination.stat().st_size,'bytes')
