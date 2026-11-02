"""Rebuild Howe Sound (AHSBR) Tracheophyta inputs for howe-sound-mapping-2026, replacing the
Galiano-derived ultimate list. Mirrors prepare_summary.R, prepare_summary_final.R, prepare_obs.R and
the label step of intersectShapes.R. Solow: site formula, baseline 1897, analysis 2024."""
import pandas as pd, numpy as np, os, math, csv
# Run from the repo root; expects the Howe_Sound project at ../adfsimon-bioinfo/Howe_Sound
M='..'; TD='tabular_data'; OUT='tabular_data'
BASE,ANA=1897,2024
STAMP="2026-06-16"   # keep existing filenames so config.json5 / layouts / built site need no changes
def W(df,name):
    df.to_csv(f"{OUT}/{name}",index=False,na_rep="",quoting=csv.QUOTE_MINIMAL,lineterminator="\r\n")
    print(f"wrote {name}: {len(df)} rows")
rd=lambda p: pd.read_csv(p,dtype=str,keep_default_na=False,na_values=[]).replace({"NA":""})   # fread reads "NA" as missing
# ---------- inputs
S26=rd(f"{M}/adfsimon-bioinfo/Howe_Sound/2026_synthesis/summary/Howe_Sound_Tracheophyta_summary_2026-04-20.csv")
S24=rd(f"{M}/adfsimon-bioinfo/Howe_Sound/review/Plantae_et_Chromista/vascular_plants/outputs/vascular_plant_summary_resynthesized_2024-11-14.csv")
CAT=rd(f"{M}/adfsimon-bioinfo/Howe_Sound/consolidate_records/Plantae_et_Chromista/vascular_plants/synthesized/Howe_Sound_vascular_plant_records_consolidated.csv")
LAB=rd(f"{TD}/Howe_Sound_vascular_plant_records_consolidated_2024-11-labels.csv")
A24=rd(f"{TD}/vascular_plant_summary_resynthesized_2024-11-assigned.csv")
TREE=pd.concat([rd(f"{TD}/vascular_plant_summary_resynthesized_2024-11-assigned-taxa.csv"),
                rd(f"{TD}/Howe_Sound_vascular_plant_records_consolidated_2024-11-assigned-taxa.csv")]).drop_duplicates('id')
assert (CAT.scientificName.values==LAB.scientificName.values).all() and (CAT.occurrenceID.values==LAB.occurrenceID.values).all()
# ---------- summary base
stub=S26.reportingStatus.eq('')
stubs=S26[stub]; summ=S26[~stub].copy()
RENAME={"Heterocodon rariflorum":"Heterocodon rariflorus","Ranunculus aquatilis":"Ranunculus aquatilis complex"}
CAT['taxonName']=CAT.scientificName.replace(RENAME)
missing=sorted(set(CAT.taxonName)-set(summ.scientificName))
restore=S24[S24.scientificName.isin(missing)]
summ=pd.concat([summ,restore[summ.columns]]).sort_values('scientificName',key=lambda s:s.str.replace('× ','')).reset_index(drop=True)
print("stubs excluded:",len(stubs),"| restored from 2024-11-14:",list(restore.scientificName))
print('catalogue taxa with no summary entry (dropped by the prepare_obs join):',sorted(set(CAT.taxonName)-set(summ.scientificName)))
CAT['linkName']=CAT.taxonName
# ---------- catalogue-derived Solow + provenance
CAT['_yr']=pd.to_numeric(CAT.eventDate.str[:4],errors='coerce')
def solow(df):
    d=df[df._yr.notna()].drop_duplicates('eventDate'); n=len(d)
    if n==0: return pd.Series({'solow_BF':np.nan,'solow_EP':np.nan,'solow_PP':np.nan})
    T=ANA-BASE; tn=d._yr.max()-BASE
    if tn>=T: B=math.inf
    elif tn<=0: B=0.0
    elif n==1: B=1/math.log(T/tn)
    else: B=(n-1)/((T/tn)**(n-1)-1)
    PP=1.0 if B==math.inf else B/(1+B)
    return pd.Series({'solow_BF':B if B==math.inf else round(B,3),'solow_EP':round(1-PP,3),'solow_PP':round(PP,3)})
sol=CAT.groupby('taxonName')[['_yr','eventDate']].apply(solow)
prov=CAT.groupby('taxonName').basisOfRecord.apply(lambda s:'voucher' if s.isin(['PRESERVED_SPECIMEN','PreservedSpecimen']).any() else 'no_voucher')
# ---------- ultimate list (same 45 columns as before)
def pconcern(s):
    s=str(s).strip()
    if len(s)>1 and s[0]=='S' and s[1].isdigit(): return 'concern' if int(s[1])<=3 else 'secure'
    return 'unknown'
U=pd.DataFrame({
 "taxonName":summ.scientificName,"taxon_author":summ.scientificNameAuthorship,"subtaxon_author":summ.subtaxonAuthorship,"commonName":summ.commonName,
 **{c:summ[c] for c in ["kingdom","phylum","subphylum","superclass","class","subclass","superorder","order","suborder","superfamily","family","subfamily","tribe","hybrid","subspecies","variety"]},
 "introduction_status":summ.establishmentMeans,"provincial_conservation_status":summ.provincialStatus,"national_conservation_status":summ.nationalStatus,
 "occurrence_status":summ.reportingStatus,"observation":summ.iNatObservationStatus,
 "last_record_date":summ.lastReported,"last_record_observer":summ.lastReportedBy,"last_record_soruce":summ.lastReportedSource,"last_record_ID":summ.lastReportedCollectionNumber,
 "gbif_ID":summ.lastReportedGBIF,"first_record_date":summ.firstReported,"first_record_observer":summ.firstReportedBy,
 "linkTaxonID":"","notes":summ.notes,"ID":summ.ID,"stats_code":summ.statsCode,"linkName":summ.scientificName})
U['graminoid_status']=np.where(U.family.isin(['Poaceae','Cyperaceae','Juncaceae','Typhaceae']),'graminoid','non-graminoid')
U['infrataxon_status']=np.where(U.taxonName.str.contains(r' (?:ssp|subsp|var)\. '),'infrataxon','non-infrataxon')
U['provincial_concern']=U.provincial_conservation_status.map(pconcern)
U['national_concern']=np.where(U.national_conservation_status.str.strip()!='','concern','unknown')
U['provenance_status']=U.taxonName.map(prov).fillna('unknown')
U=U.join(sol,on='taxonName')
U['solow_BF']=U.solow_BF.map(lambda b:'Inf' if b==math.inf else b)
W(U,f"AHSBR_Tracheophyta_ultimate-list_{STAMP}.csv")
stubs.to_csv(f"{M}/adfsimon-bioinfo/Howe_Sound/2026_synthesis/summary/Howe_Sound_Tracheophyta_summary_2026-04-20_unresolved-stubs.csv",index=False)
ULTC=CAT.drop(columns=['_yr'])
W(ULTC,f"AHSBR_Tracheophyta_ultimate-catalogue_{STAMP}.csv")
# ---------- prepare_summary.R
orig=U[["taxonName","introduction_status","occurrence_status","infrataxon_status","provincial_concern","provenance_status","solow_EP","phylum"]].rename(columns={"occurrence_status":"reportingStatus","taxonName":"scientificName"})
W(orig,f"AHSBR_Tracheophyta_ultimate-merged-summary_{STAMP}-orig.csv")
# ---------- name assignment (from the Nov 2024 assignBNames outputs)
idmap=dict(zip(A24.scientificName,A24.iNaturalistTaxonId)); nsmap=dict(zip(A24.scientificName,A24.nameStatus))
catid=LAB.drop_duplicates('scientificName').set_index('scientificName')
inv={v:k for k,v in RENAME.items()}
def assign(n):
    if n in idmap and idmap[n]!='': return idmap[n],nsmap[n]
    src=inv.get(n,n)
    if src in catid.index: return catid.at[src,'iNaturalistTaxonId'],catid.at[src,'nameStatus']
    return '',''
ass=orig.scientificName.map(assign)
T=TREE.set_index('id')
RANKS=["kingdom","subphylum","class","subclass","superorder","order","infraorder","superfamily","family","subfamily","tribe","genus"]
def lineage(i):
    out={}; cur=i
    while cur and cur in T.index:
        r=T.loc[cur]; out.setdefault(r['rank'],(r.iNaturalistTaxonName,cur)); cur=r.parentId
    return out
def taxcols(i):
    d={c:'' for c in RANKS+["species","subspecies","variety"]}
    if not i: return d
    L=lineage(i)
    for rk in RANKS:
        if rk in L: d[rk]=L[rk][0]
    own=T.at[i,'rank']; nm=T.at[i,'iNaturalistTaxonName'].split()
    if own in ('species','subspecies','variety') and len(nm)>=2: d['species']=nm[1]
    elif 'species' in L: d['species']=L['species'][0].split()[-1]
    if 'subspecies' in L: d['subspecies']=L['subspecies'][0]
    if 'variety' in L: d['variety']=L['variety'][0]
    return d
assigned=orig.copy()
assigned['iNaturalistTaxonId']=[a[0] for a in ass]
assigned['iNaturalistTaxonName']=[T.at[a[0],'iNaturalistTaxonName'] if a[0] in T.index else '' for a in ass]
tc=pd.DataFrame([taxcols(a[0]) for a in ass])
for c in ["kingdom","subphylum","class","subclass","superorder","order","infraorder","superfamily","family","subfamily","tribe","genus","species","subspecies","variety"]:
    assigned[c]=tc[c].values
assigned['nameStatus']=[a[1] for a in ass]
mism=assigned[assigned.iNaturalistTaxonId==''][['scientificName']].rename(columns={'scientificName':'taxonName'}); mism['originalName']=mism.taxonName
W(mism,f"AHSBR_Tracheophyta_ultimate-merged-summary_{STAMP}-mismatches.csv")
W(assigned,f"AHSBR_Tracheophyta_ultimate-merged-summary_{STAMP}-assigned.csv")
need=set(i for i in assigned.iNaturalistTaxonId if i); keep=set()
for i in need:
    cur=i
    while cur and cur in T.index and cur not in keep: keep.add(cur); cur=T.at[cur,'parentId']
taxa=TREE[TREE.id.isin(keep)]
W(taxa,f"AHSBR_Tracheophyta_ultimate-merged-summary_{STAMP}-assigned-taxa.csv")
# ---------- prepare_summary_final.R
asum=assigned.copy(); asum['inSummary']='1'
dup=asum[asum.duplicated('iNaturalistTaxonId',keep=False)&(asum.iNaturalistTaxonId!='')]
if len(dup):
    W(dup,f"AHSBR_Tracheophyta_ultimate-merged-summary_{STAMP}-assigned-dupes.csv")
    asum=asum[~asum.index.isin(dup.index)]
print("duplicate iNat IDs removed from summary (as prepare_summary_final.R does):",list(dup.scientificName))
merged=taxa.merge(asum.drop(columns=['iNaturalistTaxonName']),left_on='id',right_on='iNaturalistTaxonId',how='outer',sort=False)
merged=merged.drop(columns=['iNaturalistTaxonId',"kingdom","phylum","class","order","infraorder","superfamily","subfamily","genus","family","subphylum","subclass","superorder","tribe"])
merged['solow_EP']=pd.to_numeric(merged.solow_EP,errors='coerce').fillna(0)
merged=merged[["id","parentId","iNaturalistTaxonName","commonName","rank","iNaturalistTaxonImage","scientificName","introduction_status","reportingStatus","infrataxon_status","provincial_concern","provenance_status","solow_EP","species","subspecies","variety","nameStatus","inSummary"]]
W(merged,f"AHSBR_Tracheophyta_ultimate-merged-summary_{STAMP}-prepared-taxa.csv")
# ---------- prepare_obs.R
f=ULTC.drop(columns=["day","month","year","phylum","kingdom","class","order","family","linkName","basisOfRecord","scientificNameAuthorship","taxonRank","establishmentMeans","provincialStatus","country","countryCode","stateProvince","occurrenceStatus"])
f['BEC']=LAB.BEC.values; f['Protected']=LAB.Protected.values      # intersectShapes labels, row-aligned
empty=[c for c in f.columns if c not in('BEC','Protected') and (f[c].str.strip()=='').all()]
f=f.drop(columns=empty)
a=assigned[['scientificName','iNaturalistTaxonId']].rename(columns={'scientificName':'taxonName'})
w=f.merge(a,on='taxonName',how='inner')
w=w[(w.iNaturalistTaxonId!='')&(w.iNaturalistTaxonId!='0')]
w=w.sort_values('taxonName',kind='stable')
cols=['taxonName']+[c for c in f.columns if c not in('taxonName','BEC','Protected')]+['iNaturalistTaxonId']
W(w[cols],f"AHSBR_Tracheophyta_ultimate-catalogue_{STAMP}-selected-orig.csv")
W(w[cols+['BEC','Protected']],f"AHSBR_Tracheophyta_ultimate-catalogue_{STAMP}-selected-labels.csv")
print("selected-orig columns:",cols)
