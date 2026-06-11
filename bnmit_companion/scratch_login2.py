import requests
from bs4 import BeautifulSoup
import urllib3
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
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
print("\n=== STEP 1: USN + DOB ===")
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

# Find all hidden fields
csrf_token = None
hidden_fields = {}
for input_tag in soup.find_all('input', type='hidden'):
    name = input_tag.get('name', '')
    val = input_tag.get('value', '')
    if name:
        hidden_fields[name] = val
    if len(name) == 32 and all(c in '0123456789abcdef' for c in name):
        csrf_token = name

print(f"CSRF Token: {csrf_token}")
print(f"Hidden fields: { {k: (v[:20] if len(v)>20 else v) for k,v in hidden_fields.items()} }")

# Step 2 - with allow_redirects=False to see what happens
print("\n=== STEP 2: Verification (no redirect) ===")
payload_step2 = {
    'idType': '1',
    'enteredid': '5656',
    'option': 'com_user',
    'task': 'login',
    'username': '1bg24cs413',
    'passwd': '2003-07-12',
    'remember': 'No',
    'return': hidden_fields.get('return', ''),
    'token': '',
    'action': 'result_form',
}
if csrf_token:
    payload_step2[csrf_token] = '1'

r_step2 = session.post(base_url + 'index.php', data=payload_step2, allow_redirects=False)
print(f"Step 2 status: {r_step2.status_code}")
print(f"Step 2 Set-Cookie: {r_step2.headers.get('Set-Cookie', 'NONE')}")
print(f"Step 2 Location: {r_step2.headers.get('Location', 'NONE')}")
print(f"Cookies after step2: {session.cookies.get_dict()}")

# Now follow redirect manually
if 'Location' in r_step2.headers:
    redirect_url = r_step2.headers['Location']
    print(f"\n=== FOLLOWING REDIRECT ===")
    print(f"URL: {redirect_url}")
    print(f"Cookies being sent: {session.cookies.get_dict()}")
    
    r_dash = session.get(redirect_url)
    print(f"Dashboard status: {r_dash.status_code}")
    print(f"Dashboard URL after redirects: {r_dash.url}")
    print(f"Cookies after dashboard: {session.cookies.get_dict()}")
    
    dash_soup = BeautifulSoup(r_dash.text, 'html.parser')
    title = dash_soup.title.string if dash_soup.title else 'NO TITLE'
    print(f"Page title: {title}")
    
    # Check for key markers
    markers = ['cn-stu-data', 'com_studentdashboard', 'cn-stu-data1', 'cn-welcome', 
               'login-form', 'idType', 'enteredid', 'loginOtp', 'bb.generate']
    print("\nPage content markers:")
    for m in markers:
        found = m in r_dash.text
        print(f"  '{m}': {found}")
    
    # Print a meaningful chunk
    print(f"\nDashboard HTML length: {len(r_dash.text)}")
    
    # Find key elements
    body_text = dash_soup.get_text()[:500]
    print(f"\nPage text preview:\n{body_text}")
    
    # Check if it's actually a login page
    if dash_soup.find('form', id='login-form'):
        print("\n!!! WARNING: Redirected back to LOGIN page !!!")
        # Check what kind of login page
        if 'loginOtp' in r_dash.text:
            print("It's the USN+DOB login page (step 1)")
        elif 'enteredid' in r_dash.text:
            print("It's the verification page (step 2)")
    
    # Check if page contains any student data class markers
    stu_data = dash_soup.find(class_='cn-stu-data')
    print(f"\n.cn-stu-data element: {stu_data}")
    
    # Check for billboard charts
    scripts = dash_soup.find_all('script')
    for s in scripts:
        if s.string and 'bb.generate' in s.string:
            print("\nFound billboard chart data!")
            # Print chart snippet
            idx = s.string.find('bb.generate')
            print(s.string[idx:idx+200])
    
else:
    print("\nNo redirect - checking Step 2 response body:")
    print(r_step2.text[:1000])
