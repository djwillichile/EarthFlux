# Download hourly observations (product RE1022, monthly sheet) and hourly
# maxima of instantaneous global radiation (product RE1019) of the DMC
# SACLIM portal (climatologia.meteochile.gob.cl; public data, cite DMC) for
# the stations listed in dmc_stations_box.csv. Usage, from the EarthFlux root:
#   python3 -I research/cedes2027/scripts/01_download_dmc.py 2019 2
# Output: <cache>/dmc/dmc_RE1022_hourly_YYYYMM.csv and
#         <cache>/dmc/dmc_RE1019_radmax_YYYYMM.csv (raw strings, UTC hours).
import csv,re,html,time,subprocess,os,sys
base='https://climatologia.meteochile.gob.cl/application'
Y,M=int(sys.argv[1]),int(sys.argv[2])
D=os.environ.get('CEDES_DMC_DIR','research/cedes2027/data/raw/cache/dmc')
st=list(csv.DictReader(open(os.path.join(D,'dmc_stations_box.csv'))))
tmp=os.path.join(D,'tmp.html')
def get(url):
    r=subprocess.run(['curl','-sS','-m','180','-o',tmp,'-w','%{http_code}',url],capture_output=True,text=True)
    return r.stdout, open(tmp,encoding='utf-8',errors='replace').read() if os.path.exists(tmp) else ''
def cells(r): return [html.unescape(re.sub(r'<[^>]+>','',x)).strip() for x in re.findall(r'<td[^>]*>(.*?)</td>',r,re.S)]
hourly=[];rad=[]
for s in st:
    code=s['id']
    sc,h=get(f'{base}/mensualb/hojaMensualDatos/{code}/{Y}/{M}')
    seen=set();n=0
    for r in re.findall(r'<tr[^>]*>(.*?)</tr>',h,re.S):
        c=cells(r)
        if len(c)==23 and re.match(r'\d\d:\d\d',c[1]):
            k=(c[0],c[1])
            if k in seen: continue
            seen.add(k);n+=1
            hourly.append(dict(station_id=code,date_utc=f'{Y}-{M:02d}-{c[0]}',hour_utc=c[1],wind_dir_deg=c[2],wind_speed_kt=c[3],t_air_c=c[4],t_dew_c=c[5],t_min_c=c[6],t_max_c=c[7],rh_pct=c[8],p_station_qfe_hpa=c[13],p_sealevel_qff_hpa=c[14],p_qnh_hpa=c[15]))
    time.sleep(1)
    sc2,h2=get(f'{base}/mensual/radiacionGlobalInstantanea/{code}/{Y}/{M}')
    m=0
    for r in re.findall(r'<tr[^>]*>(.*?)</tr>',h2,re.S):
        c=cells(r)
        if len(c)==27 and c[0].isdigit():
            for hh in range(24):
                rad.append(dict(station_id=code,date_utc=f'{Y}-{M:02d}-{int(c[0]):02d}',hour_utc=f'{hh:02d}:00',rg_hourly_max_wm2=c[1+hh]))
            m+=1
    print(code,s['name'],s['owner'],sc,n,sc2,m,flush=True)
    time.sleep(1)
def wr(fn,rows):
    if rows:
        with open(fn,'w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
wr(os.path.join(D,f'dmc_RE1022_hourly_{Y}{M:02d}.csv'),hourly)
wr(os.path.join(D,f'dmc_RE1019_radmax_{Y}{M:02d}.csv'),rad)
