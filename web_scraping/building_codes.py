# run the code below to activate the virtual enviroment to activate the dependencies
# source .venv/bin/activate

import requests, json, os
from bs4 import BeautifulSoup

base_url = "https://www.csulb.edu/"

r = requests.get("https://www.csulb.edu/maps/building-names-codes")
soup = BeautifulSoup(r.content, 'lxml')
table = soup.find_all('tr')

# gets all the table rows starting at index 1, skipping the table row header
body = table[1:]

# empty lists to store the building acronyms and names
building_acronyms = []
building_names = []

# for loop to get all the 'td' HTML elements from each row
for row in body:
    cols = row.find_all('td')
    # accessing the first 'td' element and storing the string in a variable
    acronym = cols[0].text.strip()
    # accessing the second 'td' element and storing the string in a variable
    building = cols[1].text.strip()
    # if the acronym is equal to &nbsp, skip and continue the for loop
    if acronym == "":
        continue
    else:
        # store the building acronym in the building_acronyms list
        building_acronyms.append(acronym)
        # store the building name in the building_names list
        building_names.append(building)
        
# create a dictonary, using the building acronyms and names
building_acronyms_and_names = dict(zip(building_acronyms, building_names))

# Save the json file to the Flutter assets folder
# Get the project root 
root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Path to Flutter assets folder
output_path = os.path.join(root_dir, 'assets', 'building_codes.json')
os.makedirs(os.path.dirname(output_path), exist_ok=True)

with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(
        building_acronyms_and_names,
        f,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    )