with open(r'C:\SwiftAIERP\backend\cmd\auth-service\main.go', 'r', encoding='utf-8') as f:
    content = f.read()

# Check routes
routes = [
    'POST("/bom", prodHandler.CreateBOM)',
    'GET("/bom", prodHandler.ListBOMs)',
    'GET("/bom/:id", prodHandler.GetBOM)',
    'POST("/bom/:id/items", prodHandler.AddBOMItem)',
    'POST("/bom/explode", prodHandler.ExplodeBOM)',
]

for r in routes:
    if r in content:
        print(f'  OK: {r}')
    else:
        print(f'  MISSING: {r}')

# Check for ordering issues - any route before /bom that could conflict
idx_bom = content.find('GET("/bom"')
if idx_bom > 0:
    print(f'\nGET /bom found at position {idx_bom}')
    # Check around it
    print(content[idx_bom-100:idx_bom+100])
