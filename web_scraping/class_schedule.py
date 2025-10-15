# run the code below to activate the virtual enviroment to activate the dependencies
# source .venv/bin/activate

import requests
from bs4 import BeautifulSoup
import json

base_url = "https://www.csulb.edu/"
r_no_hash = 'https://web.csulb.edu/depts/enrollment/registration/class_schedule/Fall_2025/By_Subject/'
r = requests.get("https://web.csulb.edu/depts/enrollment/registration/class_schedule/Fall_2025/By_Subject/#")
soup = BeautifulSoup(r.content, 'lxml')
table = soup.find('div', class_='indexList')
ul_rows = table.find_all('ul')

class_names = []
class_links = []

for ul in ul_rows:
    li_rows = ul.find_all('li')
    for li in li_rows:
        for a in li.find_all('a'):
            class_names.append(a.text.strip())
            class_links.append(r_no_hash + a['href'])

class_names_and_links = dict(zip(class_names, class_links))

# json_string_formatted = json.dumps(class_names_and_links, indent=4)
# print("\nFormatted JSON string:")
# print(json_string_formatted)

# page = requests.get(class_links[0])
# page_soup = BeautifulSoup(page.content, 'lxml')

# sessions = page_soup.find_all('div', class_='session')

classes = []
index = 0
for link in class_links:
    page = requests.get(link)
    page_soup = BeautifulSoup(page.content, 'lxml')
    sessions = page_soup.find_all('div', class_='session')

    for indiv_session in sessions:
        session_duration = indiv_session.find('h2', class_='sessionTitle')
        if session_duration:
            session_title = session_duration.get_text(strip=True)
        else:
            session_title = "Session: Aug 25 - Dec 10,2025"
        courseBlocks = indiv_session.find_all('div', class_='courseBlock')
        for indiv_courseBlock in courseBlocks:
            rows = indiv_courseBlock.find_all('tr')
            for indiv_row in rows:
                cols = indiv_row.find_all('td')
                if len(cols) < 9:
                    continue
                days = cols[5].text
                time = cols[6].text
                location = cols[8].text
                if cols[8].text == "ONLINE-ONLY":
                    continue
                else:
                    classes.append([class_names[index], session_title, days, time, location])
    index = index + 1


# Write the list of classes to a json file
with open("classes.json", "w") as f:
    json.dump(
        classes,
        f,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    )