import flash.display.MovieClip;
import flash.display.Shape;
import flash.display.Graphics;
import flash.display.Sprite;

import flash.events.MouseEvent;
import flash.events.Event;

import flash.text.TextFormat;
import flash.text.TextFieldAutoSize;

import Settings;

class Txt {
   public var lines:Array<flash.text.TextField>;
   var format:flash.text.TextFormat;
   var x:Float;
   var y:Float;
   var line_height:Float;

   public function new(x:Float=0,y:Float=0,text:String="",size:Int=Settings.fontsize_std,color=Colors.black) {
      this.x= x;
      this.y= y;
      lines= new Array<flash.text.TextField>();      

      format= new flash.text.TextFormat();
      format.size= size;
      format.font= Settings.font;

      //addline(text);
   
      var tmp= new flash.text.TextField();
      lines[0]= tmp;
      lines[0].defaultTextFormat= format;
      lines[0].textColor= color;
      lines[0].text= text;
      lines[0].x= x;
      lines[0].y= y;
      line_height= lines[0].textHeight;
      flash.Lib.current.addChild(lines[0]);
   
   }
   public function addline(t:String) {
      var index= lines.length;
      lines[index]= new flash.text.TextField();
      lines[index].defaultTextFormat= format;
      lines[index].text= t;
      lines[index].x= x;
      lines[index].y= y+line_height*index;
      flash.Lib.current.addChild(lines[index]);
   }
   public function update(t:String,line=0) {
      lines[line].text= t;
   }
   public function delete() {
      hide();
   }
   public function hide() {
      for(l in lines.iterator()) {
         flash.Lib.current.removeChild(l);
      }
   }
   public function show() {
      for(l in lines.iterator()) {
         flash.Lib.current.addChild(l);
      }
   }
}

class Button extends flash.text.TextField {
   public function new(x:Float, y:Float, t="", size=Settings.fontsize_std) {
      super();
      this.x= x;
      this.y= y;
      text= t;
      background= true;
      backgroundColor= Colors.button;
      border= true;
      borderColor= Colors.button_border;
          
      var format= new flash.text.TextFormat();
      format.size= size;
      format.font= Settings.font;
      defaultTextFormat= format;
             
      //height= textHeight;
      //width= textWidth;
      autoSize= TextFieldAutoSize.CENTER;
         
      flash.Lib.current.addChild(this);
         
      this.addEventListener(MouseEvent.MOUSE_OVER,mouse_over);
      this.addEventListener(MouseEvent.MOUSE_OUT,mouse_out);
   }
      
   function mouse_over(e:MouseEvent) {
      backgroundColor= Colors.button_hover;
   }
   function mouse_out(e:MouseEvent) {
      backgroundColor= Colors.button;
   }
   function onclick(e:MouseEvent);

   public function hide() {
      flash.Lib.current.removeChild(this);
   }
   public function show() {
      flash.Lib.current.addChild(this);
   }
}

