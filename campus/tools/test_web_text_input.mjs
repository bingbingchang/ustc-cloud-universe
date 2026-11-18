import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
test('browser key input masks, clears hidden values and only accepts same-origin parent settings actions',()=>{
  const fields=[],listeners={},calls=[],parent={};
  const document={activeElement:null,body:{appendChild:input=>fields.push(input)},getElementById:()=>({focus(){}}),
    createElement(){return {style:{},value:'',selectionStart:0,selectionEnd:0,setAttribute(){},addEventListener(){},
      focus(){document.activeElement=this},blur(){document.activeElement=null},setSelectionRange(){}}}};
  const window={parent,addEventListener:(name,callback)=>listeners[name]=callback};
  vm.runInNewContext(readFileSync(new URL('../godot/web/text_input.js',import.meta.url),'utf8'),{window,document,location:{origin:'https://campus.example'}});
  const bridge=window.CampusTextInput;bridge.init((...args)=>calls.push(args));
  const sync=(visible,secret)=>bridge.sync('api_key','科大 API Key','fake-browser-key','',0,0,200,40,1,visible,true,16,secret);
  sync(true,true);assert.equal(fields[0].type,'password');assert.equal(fields[0].maxLength,512);
  assert.equal(fields[0].autocomplete,'off');assert.equal(fields[0].value,'fake-browser-key');
  sync(true,false);assert.equal(fields[0].type,'text');
  sync(false,true);assert.equal(fields[0].value,'');assert.equal(fields[0].style.display,'none');
  listeners.message({origin:'https://attacker.example',source:parent,data:{type:'campus-ai-settings'}});
  listeners.message({origin:'https://campus.example',source:{},data:{type:'campus-ai-settings'}});
  assert.equal(calls.length,0);
  listeners.message({origin:'https://campus.example',source:parent,data:{type:'campus-ai-settings'}});
  assert.deepEqual(calls,[['settings','','open']]);
});
