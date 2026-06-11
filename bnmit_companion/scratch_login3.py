import requests
from bs4 import BeautifulSoup
import urllib3
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

base_url = 'https://bnmit-students.contineo.in/parentseven/'

session = requests.Session()
session.verify = False
session.headers.update({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Origin': 'https://bnmit-students.contineo.in',
    'Referer': base_url,
})

# Init
print("=== INIT ===")
r_init = session.get(base_url)
print(f"Status: {r_init.status_code}, Cookie: {session.cookies.get_dict()}")

# Step 1
print("\n=== STEP 1 ===")
session.headers['Referer'] = base_url
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
print(f"Status: {r_step1.status_code}")

soup = BeautifulSoup(r_step1.text, 'html.parser')
csrf_token = None
for inp in soup.find_all('input', type='hidden'):
    name = inp.get('name', '')
    if len(name) == 32 and all(c in '0123456789abcdef' for c in name):
        csrf_token = name
print(f"CSRF: {csrf_token}")

# Step 2
print("\n=== STEP 2 ===")
session.headers['Referer'] = base_url + 'index.php'
payload_step2 = {
    'idType': '1',
    'enteredid': '5656',
    'option': 'com_user',
    'task': 'login',
    'username': '1bg24cs413',
    'passwd': '2003-07-12',
    'remember': 'No',
    'return': '',
    'token': '',
    'action': 'result_form',
}
if csrf_token:
    payload_step2[csrf_token] = '1'

r_step2 = session.post(base_url + 'index.php', data=payload_step2, allow_redirects=False)
print(f"Status: {r_step2.status_code}")
print(f"Location: {r_step2.headers.get('Location', 'NONE')}")
new_cookie = r_step2.headers.get('Set-Cookie', '')
print(f"Set-Cookie: {new_cookie}")

# Follow redirect with correct Referer
if r_step2.status_code in (301, 302, 303):
    redirect_url = r_step2.headers['Location']
    print(f"\n=== FOLLOWING REDIRECT (attempt 1 - with allow_redirects=True) ===")
    session.headers['Referer'] = base_url + 'index.php'
    
    # Try follow redirect but track what happens step by step
    r_dash = session.get(redirect_url, allow_redirects=False)
    print(f"Dashboard direct GET status: {r_dash.status_code}")
    print(f"Dashboard Set-Cookie: {r_dash.headers.get('Set-Cookie', 'NONE')}")
    print(f"Dashboard Location: {r_dash.headers.get('Location', 'NONE')}")
    print(f"Dashboard cookies: {session.cookies.get_dict()}")
    
    if r_dash.status_code == 200:
        ds = BeautifulSoup(r_dash.text, 'html.parser')
        title = ds.title.string if ds.title else 'NO TITLE'
        print(f"Page title: {title}")
        has_stu = 'cn-stu-data' in r_dash.text
        has_login = 'login-form' in r_dash.text
        print(f"Has student data: {has_stu}")
        print(f"Has login form: {has_login}")
        if has_stu:
            print("SUCCESS! Dashboard loaded!")
            # Print student info
            stu = ds.find(class_='cn-stu-data')
            if stu:
                print(f"Student data: {stu.get_text()[:200]}")
        else:
            print(f"Page text: {ds.get_text()[:300]}")
    elif r_dash.status_code in (301, 302, 303):
        redirect2 = r_dash.headers.get('Location', '')
        print(f"Got another redirect to: {redirect2}")
        r_dash2 = session.get(redirect2 if redirect2.startswith('http') else base_url + redirect2, allow_redirects=False)
        print(f"After 2nd redirect: status={r_dash2.status_code}")
        ds2 = BeautifulSoup(r_dash2.text, 'html.parser')
        print(f"Title: {ds2.title.string if ds2.title else 'NONE'}")
        has_stu = 'cn-stu-data' in r_dash2.text
        print(f"Has student data: {has_stu}")
        if has_stu:
            print("SUCCESS on 2nd redirect!")
            print(f"Cookies after 2nd redirect: {session.cookies.get_dict()}")
            # Now let's request the dashboard page again with the same session
            print("\n=== REQUESTING DASHBOARD AGAIN WITH ACTIVE SESSION ===")
            r_dash_again = session.get(base_url + 'index.php?option=com_studentdashboard&controller=studentdashboard&task=dashboard', allow_redirects=False)
            print(f"Dashboard status code on second hit: {r_dash_again.status_code}")
            print(f"Location: {r_dash_again.headers.get('Location', 'NONE')}")
            if r_dash_again.status_code in (301, 302, 303):
                # Follow redirect
                loc = r_dash_again.headers.get('Location', '')
                r_dash_again_follow = session.get(loc if loc.startswith('http') else base_url + loc, allow_redirects=False)
                print(f"Followed redirect: status={r_dash_again_follow.status_code}")
                print(f"Has student data: {'cn-stu-data' in r_dash_again_follow.text}")
            else:
                print(f"Has student data: {'cn-stu-data' in r_dash_again.text}")
        else:
            print(f"Page text: {ds2.get_text()[:300]}")

# Test: what if we DON'T follow the 303 at all and let requests handle it?
print("\n\n=== FULL TEST WITH allow_redirects=True ===")
session2 = requests.Session()
session2.verify = False
session2.headers.update({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
})

session2.get(base_url)
session2.headers['Referer'] = base_url
r1 = session2.post(base_url + 'index.php', data=payload_step1)
session2.headers['Referer'] = base_url + 'index.php'
soup2 = BeautifulSoup(r1.text, 'html.parser')
csrf2 = None
for inp in soup2.find_all('input', type='hidden'):
    name = inp.get('name', '')
    if len(name) == 32 and all(c in '0123456789abcdef' for c in name):
        csrf2 = name
p2 = dict(payload_step2)
if csrf2:
    p2[csrf2] = '1'

# Let requests follow ALL redirects naturally
r2 = session2.post(base_url + 'index.php', data=p2, allow_redirects=True)
print(f"Final status: {r2.status_code}")
print(f"Final URL: {r2.url}")
for i, h in enumerate(r2.history):
    print(f"Hop {i}: URL={h.url}, Status={h.status_code}")
    print(f"  Response headers: {dict(h.headers)}")
    print(f"  Request headers: {dict(h.request.headers)}")
    print(f"  Cookies after this hop: {session2.cookies.get_dict()}")
print(f"Final response headers: {dict(r2.headers)}")
print(f"Final request headers: {dict(r2.request.headers)}")
ds_final = BeautifulSoup(r2.text, 'html.parser')
print(f"Title: {ds_final.title.string if ds_final.title else 'NONE'}")
print(f"Has student data: {'cn-stu-data' in r2.text}")
print(f"Has login form: {'login-form' in r2.text}")
print(f"Cookies: {session2.cookies.get_dict()}")
