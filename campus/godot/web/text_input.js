// Native browser text controls preserve IME composition, paste and mobile keyboards.
(() => {
  if (window.CampusTextInput) return;
  const fields=new Map();let callback,requested='';
  const canvas=()=>document.getElementById('canvas');
  function create(name,label){
    const input=document.createElement('input');input.type=name==='api_key'?'password':'text';input.autocomplete='off';input.spellcheck=false;
    input.setAttribute('aria-label',label);input.maxLength=name==='api_key'?512:1200;
    Object.assign(input.style,{position:'fixed',zIndex:'100',display:'none',boxSizing:'border-box',margin:'0',padding:'0 10px',
      background:'#11191d',color:'#f1f4ef',border:'1px solid #b0bdb5',borderRadius:'3px',outlineOffset:'1px',
      fontFamily:'"Microsoft YaHei","PingFang SC",sans-serif'});
    let composing=false;
    input.addEventListener('compositionstart',()=>{composing=true;});
    input.addEventListener('compositionend',()=>{composing=false;callback?.(name,input.value,'edit');});
    input.addEventListener('input',event=>{if(!event.isComposing&&!composing)callback?.(name,input.value,'edit');});
    input.addEventListener('keydown',event=>{
      event.stopPropagation();
      if(event.isComposing||composing||event.keyCode===229)return;
      if(event.key==='Enter'){event.preventDefault();callback?.(name,input.value,'submit');}
      if(event.key==='Escape'){event.preventDefault();callback?.(name,input.value,'escape');input.blur();canvas()?.focus();}
    });
    input.addEventListener('keyup',event=>event.stopPropagation());
    document.body.appendChild(input);
    const field={input,isComposing:()=>composing};fields.set(name,field);return field;
  }
  window.CampusTextInput={
    init(fn){callback=fn;
      window.addEventListener('message',event=>{
        if(event.origin===location.origin&&event.source===window.parent&&event.data?.type==='campus-ai-settings')callback?.('settings','','open');
      });
    },
    focus(name){requested=name;},
    sync(name,label,value,placeholder,x,y,width,height,scale,visible,editable,fontSize,secret=false){
      const field=fields.get(name)||create(name,label),input=field.input;
      if(!visible){
        if(document.activeElement===input){input.blur();canvas()?.focus();}
        input.style.display='none';if(name==='api_key')input.value='';return;
      }
      Object.assign(input.style,{display:'block',left:x*scale+'px',top:y*scale+'px',width:width*scale+'px',height:height*scale+'px',fontSize:fontSize*scale+'px'});
      input.placeholder=placeholder;input.disabled=!editable;input.type=secret?'password':'text';
      if(!field.isComposing()&&input.value!==value){
        const start=input.selectionStart,end=input.selectionEnd;
        input.value=value;
        if(document.activeElement===input&&start!==null)input.setSelectionRange(Math.min(start,value.length),Math.min(end,value.length));
      }
      if(requested===name&&!input.disabled){input.focus({preventScroll:true});requested='';}
    }
  };
})();
