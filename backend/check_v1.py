with open(r'C:\SwiftAIERP\backend\cmd\auth-service\main.go', 'r', encoding='utf-8') as f:
    content = f.read()

idx = content.find('v1 := r.Group("/api/v1")')
print('v1 group:', content[idx:idx+300])

# Check what routes are registered under v1
idx2 = content.find('v1.POST("/bom"')
print('\nBOM route under v1:', content[idx2:idx2+200] if idx2 >= 0 else 'NOT FOUND')

# Check for BOM POST
idx3 = content.find('POST("/bom", prodHandler.CreateBOM)')
if idx3 >= 0:
    before = content[idx3-15:idx3]
    print(f'\nBefore POST /bom: {repr(before)}')
else:
    print('\nPOST /bom NOT FOUND!')

# Find what group contains the BOM routes
# Search for the pattern around the BOM route group
import re
for m in re.finditer(r'(v1|protected)\.(POST|GET)\([^)]+bom[^)]+\)', content):
    print(f'Found BOM route: {m.group()}')
