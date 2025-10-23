import requests, json, os
from bs4 import BeautifulSoup

r = requests.get("https://www.csulb.edu/maps/building-names-codes")
soup = BeautifulSoup(r.content, 'lxml')
table = soup.find_all('tr')
body = table[1:]

building_acronyms = []
building_names = []

for row in body:
    cols = row.find_all('td')
    acronym = cols[0].text.strip()
    building = cols[1].text.strip()
    if acronym == "":
        continue
    building_acronyms.append(acronym)
    building_names.append(building)

building_acronyms_and_names = dict(zip(building_acronyms, building_names))

# === Save JSON inside /webscraping ===
current_dir = os.path.dirname(os.path.abspath(__file__))
output_path = os.path.join(current_dir, 'building_codes.json')
os.makedirs(os.path.dirname(output_path), exist_ok=True)

with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(
        building_acronyms_and_names,
        f,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    )

print(f"Saved to {output_path}")
