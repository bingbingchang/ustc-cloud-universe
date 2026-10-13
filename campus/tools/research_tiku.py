from pathlib import Path
import urllib.request,json
R=Path(__file__).resolve().parents[2]/'references/characters/tiku_boy1/research'
refs=[
('bench_reading','https://tw.lzufe.edu.cn/info/1012/11085.htm','https://tw.lzufe.edu.cn/_mediafile/cs/2016/04/19/2qzx4bui63.jpg','Long bench, elbows and book support'),
('bench_profile','https://www.sohu.com/a/872251992_121124331','https://q7.itc.cn/q_70/images03/20250317/6abf09a5d18e49a4a3ddb39c3ac43cfa.jpeg','Side view of seated reading'),
('outdoor_uniform','https://www.ourjiangsu.com/a/20211209/1639015999849.shtml','https://oss.cloud.jstv.com/cdv/cdv-npds/6CC2E06B7D3744838BD5893214827933/30D5CC8F75CB44E9BC05953CC5ABCDDE.png','Outdoor spacing and uniform cloth'),
('writing_clothes','https://news.youth.cn/jsxw/201705/t20170518_9801435.htm','https://t.m.youth.cn/magicimg/news.youth.cn/jsxw/201705/W020170518378345556853.jpg','White collar and blue trim only, not facial identity'),
('lap_book','https://tw.news.yahoo.com/%E6%96%97%E5%85%AD%E9%AB%98%E4%B8%AD%E5%AD%B8%E6%B8%AC%E6%8D%B7%E5%A0%B1-4%E7%A7%9160%E6%BB%BF%E7%B4%9A%E5%88%86-%E6%95%B8%E7%90%86%E5%89%8D%E6%A8%99%E4%BA%BA%E6%95%B8%E9%80%86%E5%8B%A2%E6%88%90%E9%95%B7%E8%BF%913%E6%88%90-075903767.html','https://s.yimg.com/ny/api/res/1.2/jpNOGpacHuKNUO7pwEZg4g--/YXBwaWQ9aGlnaGxhbmRlcjt3PTk2MDtoPTc4OA--/https%3A/media.zenfs.com/ko/chinatimes.com.tw/1e3f026c3fa7db38a212d04844429546','Forward leaning, book on lap'),
('stone_bench','https://www.sohu.com/a/390008271_243208','https://5b0988e595225.cdn.sohucs.com/q_70%2Cc_zoom%2Cw_640/images/20200422/1ac73cc6d7904133900652a604cb1009.jpeg','Book grip and quiet sitting')]
out=[]
for name,page,url,use in refs:
 item=dict(name=name,page=page,image=url,use=use,license='Unknown; research reference only, not a game texture or redistributable asset',date='2026-09-08')
 try:
  data=urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=20).read();file=name+('.png' if data.startswith(b'\x89PNG') else '.jpg');(R/file).write_bytes(data);item['file']=file;item['bytes']=len(data)
 except Exception as e:item['error']=str(e)
 out.append(item)
(R/'sources.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
print([(i['name'],i.get('bytes',i.get('error'))) for i in out])
