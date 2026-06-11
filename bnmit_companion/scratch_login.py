import requests
from bs4 import BeautifulSoup
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

session = requests.Session()
session.verify = False
session.headers.update({
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
})

base_url = 'https://bnmit-students.contineo.in/parentseven/'

# Init
print("Visiting home page...")
r_init = session.get(base_url)
print(f"Init status: {r_init.status_code}")
print(f"Init cookies: {session.cookies.get_dict()}")

# Step 1
print("\nSubmitting Step 1...")
payload_step1 = {
    'username': '1bg24cs413',
    'dd': '12',
    'mm': '07',
    'yyyy': '2003',
    'passwd': '2003-07-12',
    'option': 'com_user',
    'task': 'loginOtp',
    'token': '',
    'action': 'result_form',
}

r_step1 = session.post(base_url + 'index.php', data=payload_step1)
print(f"Step 1 status: {r_step1.status_code}")
print(f"Step 1 cookies: {session.cookies.get_dict()}")

soup = BeautifulSoup(r_step1.text, 'html.parser')

# Find CSRF token
csrf_token = None
for input_tag in soup.find_all('input', type='hidden'):
    name = input_tag.get('name', '')
    if len(name) == 32 and all(c in '0123456789abcdef' for c in name):
        csrf_token = name
        print(f"Found CSRF Token: {csrf_token}")

# Find return value
return_val = ''
for input_tag in soup.find_all('input', type='hidden'):
    if input_tag.get('name') == 'return':
        return_val = input_tag.get('value', '')
        print(f"Found return value: {repr(return_val.encode('ascii', 'backslashreplace'))}")

# Print all hidden fields to see what's there
print("\nAll hidden fields in Step 1 response:")
for input_tag in soup.find_all('input', type='hidden'):
    name = input_tag.get('name', '')
    val = input_tag.get('value', '')
    print(f"  {name}: {repr(val.encode('ascii', 'backslashreplace'))}")

# Step 2
print("\nSubmitting Step 2...")
payload_step2 = {
    'idType': '1',
    'enteredid': '5656',
    'option': 'com_user',
    'task': 'login',
    'username': '1bg24cs413',
    'passwd': '2003-07-12',
    'remember': 'No',
    'return': return_val,
    'token': '',
    'action': 'result_form',
}
if csrf_token:
    payload_step2[csrf_token] = '1'

# We might also need the dynamic name of the other token field if it exists
for input_tag in soup.find_all('input', type='hidden'):
    name = input_tag.get('name')
    if name and name not in payload_step2 and name != csrf_token:
        # Check if there is another hash-like field
        if len(name) == 32 and all(c in '0123456789abcdef' for c in name):
            payload_step2[name] = input_tag.get('value', '1')
            print(f"Added additional hidden field: {name} = {payload_step2[name]}")

r_step2 = session.post(base_url + 'index.php', data=payload_step2, allow_redirects=False)
print(f"Step 2 status: {r_step2.status_code}")
print(f"Step 2 headers: {dict(r_step2.headers)}")
print(f"Step 2 cookies: {session.cookies.get_dict()}")

if 'Location' in r_step2.headers:
    redirect_url = r_step2.headers['Location']
    print(f"Redirecting to: {redirect_url}")
    # Follow redirect
    r_redirect = session.get(redirect_url if redirect_url.startswith('http') else base_url + redirect_url)
    print(f"Redirect status: {r_redirect.status_code}")
    print(f"Redirect page contains 'com_studentdashboard': {'com_studentdashboard' in r_redirect.text}")
    print(f"Redirect page title: {BeautifulSoup(r_redirect.text, 'html.parser').title}")
else:
    print("No redirect Location header found.")
    print("Response HTML snippet:")
    print(r_step2.text[:1000])
