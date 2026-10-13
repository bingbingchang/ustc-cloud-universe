from pathlib import Path
R=Path(__file__).resolve().parents[1]
p=R/'godot/scripts/scene_life.gd';s=p.read_text(encoding='utf-8')
a=s.index('\tvar s=actors.solver;');b=s.index('\tvar g=actors.reader;',a)
s=s[:a]+'\tactors.solver.root.pose(t)\n\tvar b;var phase\n'+s[b:]
s=s.replace('var n=prop("student_"+spec[0],spec[1],spec[2]);n.name="Student_"+spec[0]','var n=prop("tiku_boy1" if spec[0]=="solver" else "student_"+spec[0],Vector3(-17,.53,147) if spec[0]=="solver" else spec[1],spec[2]);n.name="Student_"+spec[0]\n\t\tif spec[0]=="solver":n.set_script(preload("res://scripts/tiku_actor.gd"));n.prepare()')
s=s.replace('\tpose(0)','\tactors.solver.root.passerby=actors.reader.root\n\tpose(0)')
p.write_text(s,encoding='utf-8')
