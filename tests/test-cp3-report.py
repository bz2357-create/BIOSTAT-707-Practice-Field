"""Check the delivered readable report, including identifiers and diagnostic output."""
from pathlib import Path
from html.parser import HTMLParser
import re,csv
class Report(HTMLParser):
 def __init__(self):super().__init__();self.words=[];self.images=[];self.hidden=0;self.tables=0;self.figures=0
 def handle_starttag(self,t,a):
  a=dict(a)
  if t in ('script','style'):self.hidden+=1
  if t=='table':self.tables+=1
  if t=='figcaption':self.figures+=1
  if t=='img':self.images.append(a.get('src',''))
 def handle_endtag(self,t):
  if t in ('script','style'):self.hidden-=1
 def handle_data(self,s):
  if not self.hidden:self.words.append(s)
p=Path('output/checkpoint3.html');assert p.exists(),'CP3 rendered report missing'
r=Report();r.feed(p.read_text());s=re.sub(r'\s+',' ',' '.join(r.words))
for text in ['AI-use statement','3.1','3.2','3.3','3.4','3.5','3.6','3.7','3.8','ChatGPT','Codex','20%','48-hour','calibration','bootstrap','SOFA','scaled Brier','Survivor-1','Survivor-5','Death-1','Death-5']:
 assert text.lower() in s.lower(),text
assert r.tables>=12 and r.figures>=6,(r.tables,r.figures)
assert len(r.images)>=6 and all(x.startswith('data:image/') for x in r.images)
assert not re.search(r'`r\s|Error in |Execution halted',s)
for split in 'bc':
 with open(f'data/Outcomes-{split}.txt') as f:
  for row in csv.DictReader(f): assert not re.search(r'(?<![\w.])'+row['RecordID']+r'(?![\w.])',s),'Patient ID in report'
print(f'CP3 report passed: {r.tables} formatted tables, {r.figures} numbered figures, embedded resources, no B/C identifiers.')
