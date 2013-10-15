import flash.display.MovieClip;
import flash.display.Shape;
import flash.display.Graphics;
import flash.display.Sprite;

import flash.events.MouseEvent;
import flash.events.Event;

import flash.text.TextFormat;

import Math;
import haxe.Timer;

import Towers;

// ========== SETTINGS ========== //

class Settings {

   static inline private var size= 1;

   static inline public var fontsize_small= 8*size;
   static inline public var fontsize_std= 12*size;
   static inline public var fontsize_big= 22*size;

   static inline public var font= "DejaVu Sans Mono";

   static inline public var tilesize= 24;
   static inline public var creep_speedfactor= 2; // (tilesize/creep_speedfactor)%2==0 advisabe
   static inline public var bullet_speedfactor= 4;
   static inline public var wavetime= 12;
}
class Colors {
   static inline public var black= 0x000000;
   static inline public var white= 0xffffff;
   static inline public var valid= 0x00ff00; // green, for allowed actions (e.g "can build here")
   static inline public var invalid= 0xff0000; // red, to mark stuff that doesn't work (e.g. "not enough gold")
}

// ======== END SETTINGS ======== //

class Gold {
   private var amount:Int;
   var text:Txt;
      
   public function new(g:Int,t:Txt) {
      amount= g;
      text= t;
      text.update("Gold: "+Std.string(amount));
   }
   public function increase(g:Int) {
      amount+= g;
      text.update("Gold: "+Std.string(amount));
   }
   public function decrease(g:Int) {
      if(amount>=g) {
         amount-= g;
         text.update("Gold: "+Std.string(amount));
         return true;
      } else {
         return false;
      }
   }
   public function set(g:Int) {
      amount= g;
      text.update("Gold: "+Std.string(amount));
   }
   public function get() {
      return amount;
   }
   public function at_least(g:Int) {
      return (amount>=g);
   }
}

class RoutePoint {
   public var x:Float;
   public var y:Float;
   public var n:Int;
   public function new(x:Float,y:Float,n:Int=0) {
      this.x= x;
      this.y= y;
      this.n= n;
   }
}

class Route {
   var route:Array<RoutePoint>;

   public function new() {
      route= new Array();
   }

   public function add_point(p:RoutePoint) {
      // todo: handle duplicate n (replace old routepoint?)
      route.push(p);
      route.sort(sort_me);
   }
   private function sort_me(a:RoutePoint,b:RoutePoint) {
      if(a.n==b.n) { return 0; }
      else if(a.n>b.n) { return 1; }
      else { return -1; }
   }
   public function next(p:RoutePoint) {
      if(p.n==route.length) {
         // this means we are at the end of the route: return to the start
         return route[0];
      } else {
         return route[p.n];
      }
   }
}

class Bullet extends Shape {
   var source:Field;
   var target:Creep;
   var frames:Int;
   var isExploding:Bool;

   public function new(s:Field, t:Creep) {
      super();
      target= t;
      frames= 0;
      isExploding= false;
      source= s;

      this.x= source.x;
      this.y= source.y;

      graphics.lineStyle(1,0x000000);
      graphics.beginFill(0xffffff);
      graphics.drawCircle(0,0,2);
      graphics.endFill();

      this.addEventListener(flash.events.Event.ENTER_FRAME,enter_frame);

      flash.Lib.current.addChild(this);
   }

   function enter_frame(e:flash.events.Event) {
      if(!isExploding) {
         move_to_target();
      }
   }
   function move_to_target() {
      if(target.dead) {
         // instead give a new target maybe?
         flash.Lib.current.removeChild(this);
      } else {
         var bsf= Settings.bullet_speedfactor;
         if(x>target.x) x-=bsf;
         else if(x<target.x) x+=bsf;
         if(y>target.y) y-=bsf;
         else if(y<target.y) y+=bsf;
         if(is_at_target()) {
            explode();
         }
      }
   }

   function explode() {
      isExploding = true;
      // move the center a bit to the side so explosion is visible
      this.x+=5;
      this.y+=5;
      graphics.lineStyle(1,0xff0000);
      graphics.drawCircle(0,0,4);
      graphics.lineStyle(1,0x00ff00);
      graphics.drawCircle(0,0,6);
      graphics.lineStyle(1,0x0000ff);
      graphics.drawCircle(0,0,8);
      target.fire(source.tower.dmg(source.level));
      haxe.Timer.delay(endExplosion,110);
   }

   function endExplosion() {
      flash.Lib.current.removeChild(this);
   }

   function is_at_target() {
      var bsf= Settings.bullet_speedfactor;
      if(Math.abs(x-target.x)<bsf && Math.abs(y-target.y)<bsf) { return true; }
      else { return false; }
   }
}

class Field extends Sprite {
   var frames:Int;
   var creeps:Creeps;
   var info:FieldInfo;
   var range_cone:Shape;
   public var level:Int;
   public var tower:TowerType;
   public var gold:Gold;

   public function new(x:Float, y:Float, c:Creeps) {
      super(); 
      creeps= c;
      gold= c.gold;
      var ts= Settings.tilesize;
      this.x= (x+0.5)*ts;
      this.y= (y+0.5)*ts;
      tower= null;
      level= 0;
      graphics.lineStyle(1,0x000000);
      graphics.beginFill(0xffffff);
      graphics.drawCircle(0,0,3);
      graphics.endFill();
      
      this.addEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
      this.addEventListener(MouseEvent.MOUSE_OVER,mouse_over);
      this.addEventListener(MouseEvent.MOUSE_OUT,mouse_out);
      this.addEventListener(MouseEvent.MOUSE_DOWN,upgrade);
       
      flash.Lib.current.addChild(this);
   }
      
   public function cost() {
      return tower.cost(level);
   }
   public function dmg() {
      return tower.dmg(level);
   }
   public function range() {
      return tower.range(level);
   }
   public function rate() {
      return tower.rate(level);
   }
   function upgrade(e:MouseEvent) {
      if(gold.at_least(cost())) {
         gold.decrease(cost());
         level+= 1;
         info.delete();
         info= new FieldInfo(this);
      }
   }

   function show_range(show:Bool) {
      if(show) {
         range_cone= new Shape();
         range_cone.graphics.beginFill(0x000000,0.15);
         range_cone.graphics.drawCircle(this.x,this.y,range());
         range_cone.graphics.endFill();
         flash.Lib.current.addChild(range_cone);
      } else {
         flash.Lib.current.removeChild(range_cone);
      }
   }

   function mouse_over(e:MouseEvent) {
      show_range(true);
      info= new FieldInfo(this);
   }

   function mouse_out(e:MouseEvent) {
      show_range(false);
      info.delete();
   }

   function fire() {
      // search for a creep in range
      var target= creeps.closest(x,y);
      if(target.distance<=tower.range(level)) {
         new Bullet(this, target.creep);
      }
   }

   function enter_frame(e:Event) {
      if(tower!=null) {
         frames+= 1;
         if(frames>=tower.rate(level)) {
            fire();
            frames= 0;
         }
      }
   }

   public function build(t:TowerType,g:Gold) {
      tower= t;
      g.decrease(tower.cost());
      graphics.beginFill(tower.color);
      graphics.drawCircle(0,0,8);
      graphics.endFill();
   }
}

class TowerGrid extends List<Field> {
   var width:Int;
   var height:Int;
   var offsetX:Int;
   var offsetY:Int;
   var creeps:Creeps;

   public function new(c:Creeps) {
      super(); 
      width= 9;
      height= 5;
      offsetX= 1;
      offsetY= 3;
      creeps= c;
      for(x in 0...width) {
         for(y  in 0...height) {
            add(new Field(x+offsetX,y+offsetY,creeps));
         }
      }
   }
   
   public function in_grid(x:Float, y:Float) {
      var ts= Settings.tilesize;
      var startx= offsetX*ts;
      var endx= startx + width*ts;
      var starty= offsetY*ts;
      var endy= starty + height*ts;
      if(x<=startx || x>=endx || y<=starty || y>=endy) { return false; }
      else { return true; }
   }
   public function get_field(x:Float, y:Float) {
      for(f in iterator()) {
         var diffx= Math.abs(x-f.x);
         var diffy= Math.abs(y-f.y);
         if(diffx*2<Settings.tilesize && diffy*2<Settings.tilesize) {
            return f;
         }
      }
      // returns an invalid field if coords out of grid
      // check with in_grid() before calling get_field() to avoid this
      trace("Error: function get_field("+Std.string(x)+","+Std.string(y)+") returns invalid field.");
      return new Field(-1,-1,null);
   }
   public function build(f:Field, type:TowerType, g:Gold) {
      f.build(type,g);
   }
}

class TowerButton extends Sprite {
   var towers:TowerGrid;
   var clickSprite:Sprite;
   var range:Int;
   var tower_type:TowerType;
   var gold:Gold;
   var info:TowerInfo;

   public function new(t:TowerGrid,type:TowerType,g:Gold,x:Float=0,y:Float=0) {
      super();
      this.y= Settings.tilesize*(2.5+y);
      this.x= Settings.tilesize*(11.5+x);
      towers= t;
      tower_type= type;
      gold= g;
      
      graphics.lineStyle(3,0xff0000);
      graphics.beginFill(0x00ffff);
      graphics.drawCircle(0,0,10);
      graphics.endFill();
      
      this.addEventListener(MouseEvent.MOUSE_DOWN,onclick);
      this.addEventListener(MouseEvent.MOUSE_OVER,mouse_over);
      this.addEventListener(MouseEvent.MOUSE_OUT,mouse_out);
      
      flash.Lib.current.addChild(this);
   }
        
   function mouse_over(e:MouseEvent) {
      info= new TowerInfo(tower_type);
   }
   function mouse_out(e:MouseEvent) {
      info.delete();
   }
 
   function onclick(e:MouseEvent) {
      clickSprite= new Sprite();
      var s= clickSprite;
      s.x= e.stageX;
      s.y= e.stageY;
      s.graphics.beginFill(0x000000,0.2);
      s.graphics.drawCircle(0,0,tower_type.range());
      s.graphics.beginFill(Colors.invalid);
      s.graphics.drawCircle(0,0,8);
      s.graphics.endFill();
         
      s.startDrag();
         
      s.addEventListener(MouseEvent.MOUSE_DOWN,build);
      s.addEventListener(MouseEvent.MOUSE_MOVE,mouse_move);
      s.addEventListener(MouseEvent.MOUSE_OUT,mouse_move);
      flash.Lib.current.addChild(s);
   }
   function build(e:MouseEvent) {
      var s= clickSprite;
      if(can_build(s.x,s.y)) {
         towers.build(towers.get_field(s.x,s.y),tower_type,gold);
         flash.Lib.current.removeChild(s);
      } else {
         flash.Lib.current.removeChild(s);
      }
   }
   function mouse_move(e:MouseEvent) {
      var ts= Settings.tilesize;
      var s= clickSprite;

      // snap to grid
      s.x= e.stageX - e.stageX%ts + ts*0.5;
      s.y= e.stageY - e.stageY%ts + ts*0.5;
         
      // can we build here?
      if(can_build(s.x,s.y)) {
         s.graphics.beginFill(Colors.valid);
         s.graphics.drawCircle(0,0,8);
         s.graphics.endFill();
      } else {
         s.graphics.beginFill(Colors.invalid);
         s.graphics.drawCircle(0,0,8);
         s.graphics.endFill();
      }
   }
   function can_build(x:Float, y:Float) {
      if(!gold.at_least(tower_type.cost())) { return false; }
      if(!towers.in_grid(x,y)) { return false; }
      else {
         var f= towers.get_field(x,y);
         if(f.tower==null) { return true; }
         else { return false; }
      }
   }
}

class Creep extends Shape {
   var hp:Int;
   var maxhp:Int;
   var speed:Int;
   var goal:RoutePoint;
   var route:Route;
   var frames:Int;
   var creeps:Creeps;
   var gold:Gold;
   public var dead:Bool;

   public function new(r:Route,c:Creeps) {
      super();
      maxhp= 50;
      hp= maxhp;
      speed= 1;
      frames= 0;
      route= r;
      creeps= c;
      gold= c.gold;
      dead= false;
      y= 0; // top of screen
      x= 5.5*Settings.tilesize;
      goal= new RoutePoint(x,2.5*Settings.tilesize);

      graphics.lineStyle(3,0xff0000);
      graphics.beginFill(0x0000ff);
      graphics.drawCircle(0,0,10);
      graphics.endFill();
   
      draw_healthbar();   

      this.addEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
      
      flash.Lib.current.addChild(this);
   }

   function draw_healthbar() {
      var ts= Settings.tilesize;
      var percent= hp/maxhp;

      graphics.lineStyle(1,0x000000);
      graphics.beginFill(0xffffff);
      graphics.drawRect(-ts/3,-ts/12,2*ts/3,ts/6);
      graphics.lineStyle();
      graphics.beginFill(0x00ff00);
      graphics.drawRect(-ts/3,-ts/12+1,(2*ts/3)*percent,ts/6-2);
      graphics.endFill();
   }

   function i_am_dead() {
      creeps.remove(this);
      creeps.update();
      gold.increase(1);
      flash.Lib.current.removeChild(this);
      this.dead= true;
   }

   public function fire(dmg:Int) {
      hp -= dmg;
      if (hp <= 0) {
         i_am_dead();
      } else {
         draw_healthbar();
      }
   }

   function enter_frame(e:flash.events.Event) {

      frames+= 1;
      if(frames==speed) {
         move_to_goal();
         frames= 0;
      }
   }
   function move_to_goal() {
      var csf= Settings.creep_speedfactor;
      if(x>goal.x) x-=csf;
      else if(x<goal.x) x+=csf;
      if(y>goal.y) y-=csf;
      else if(y<goal.y) y+=csf;
      if(is_at_goal()) {
         goal= route.next(goal);
      }
   }
   public function set_goal(x:Float, y:Float) {
      goal.x= x;
      goal.y= y;
   }
   public function is_at_goal() {
      var csf= Settings.creep_speedfactor;
      if(Math.abs(x-goal.x)<csf && Math.abs(y-goal.y)<csf) { return true; }
      else { return false; } 
   }
}

class Creeps extends List<Creep> {
   var route:Route;
   var text:Txt;
   public var gold:Gold;

   public function new(r:Route,t:Txt,g:Gold) {
      super();
      route= r;
      text= t;
      gold= g;
      text.update("Creeps: "+Std.string(length));
   }

   public function update() {
      text.update("Creeps: "+Std.string(length));
   }

   public function closest(x:Float, y:Float) {
      var dist:Float= Math.POSITIVE_INFINITY;
      var c:Creep= null;

      var tmp:Float;
      for(f in iterator()) {
         var xdiff= Math.abs(x-f.x);
         var ydiff= Math.abs(y-f.y);
         tmp= xdiff*xdiff + ydiff*ydiff;
         if(tmp<dist) {
            dist= tmp;
            c= f;
         }
      }

      return {creep:c,distance:Math.sqrt(dist)};
   }

   public function spawn(r:Route) {
      add(new Creep(r,this));
      update();
   }
   public function spawn_wave_with_route(r:Route) {
      var wavesize= 10;    // number of creeps
      var waveival= 1500;  // time between creeps in ms
      var tmp=wavesize*waveival;
      var i=0;
      while(i<tmp) {
#if haxe3
         haxe.Timer.delay(spawn.bind(r),i);
#else
         haxe.Timer.delay(callback(spawn,r),i);
#end
         i+=waveival;
      }
   }
   
   public function spawn_wave() {
      spawn_wave_with_route(route);
   }
}

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
      for(l in lines.iterator()) {
         flash.Lib.current.removeChild(l);
      }
   }
}

class TowerInfo {
   var type:TowerType;
   var infobox:Txt;

   public function new(t:TowerType) {
      type= t;
      var ts= Settings.tilesize;
      var x= ts*11;
      var y_base= ts*5;
      var s= Settings.fontsize_small;
      infobox= new Txt(x,y_base,"Cost: "+Std.string(type.cost()),s);
      infobox.addline("Damage: "+Std.string(type.dmg()));
      infobox.addline("Rate: "+Std.string(type.rate()));
      infobox.addline("Range: "+Std.string(type.range()));
      infobox.addline("This tower shoots.");
   }

   public function delete() {
      infobox.delete();
   }
}

class FieldInfo {
   var infobox:Txt;
   var field:Field;
   var gold:Gold;

   public function new(f:Field) {
      field= f;
      gold= f.gold;
      var ts= Settings.tilesize;
      var x= ts*0.5;
      var y_base= ts*9;
      var s= Settings.fontsize_small;
      var colo:Int;
      if(gold.at_least(field.cost())) {
         colo= Colors.valid;
      } else {
         colo= Colors.invalid;
      }
      infobox= new Txt(x,y_base,"Upgrade: "+Std.string(field.cost())+" Gold",s,colo);
      infobox.addline("Damage: "+Std.string(field.dmg()));
      infobox.addline("Rate: "+Std.string(field.rate()));
      infobox.addline("Range: "+Std.string(field.range()));
      infobox.addline("This tower shoots.");
      
      field.addEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
   }

   function enter_frame(e:Event) {
      var colo:Int;
      if(gold.at_least(field.cost())) {
         colo= Colors.valid;
      } else {
         colo= Colors.invalid;
      }
      infobox.lines[0].textColor= colo;
   }

   public function delete() {
      field.removeEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
      infobox.delete();
   }
}

class Clock {
   var n:Int;
   var text:Txt;
   var timer:Timer;
   var creeps:Creeps;

   public function new(t:Int,textField:Txt,c:Creeps) {
      n= Settings.wavetime;
      text= textField;
      text.update("Next Wave: "+Std.string(n));
      timer= new Timer(t);
      timer.run= run;
      creeps= c;
   }

   function run() {
      n-=1;
      if(n==0) {
         n=Settings.wavetime;
         creeps.spawn_wave();
      }
      text.update("Next Wave: "+Std.string(n));
   }
}

class Test {

   static var creeps:Creeps;
   static var route:Route;
   static var clock:Clock;
   static var gold:Gold;
   static var towers:TowerGrid;

   // textfields
   static var time:Txt;
   static var gold_t:Txt;
   static var creeps_t:Txt;

   static function main() {

      var ts= Settings.tilesize;
      route= new Route();
      var topleft= new RoutePoint(ts*0.5,ts*2.5,1);
      var botleft= new RoutePoint(ts*0.5,ts*8.5,2);
      var botright= new RoutePoint(ts*10.5,ts*8.5,3);
      var topright= new RoutePoint(ts*10.5,ts*2.5,4);
      route.add_point(topleft);
      route.add_point(topright);
      route.add_point(botright);
      route.add_point(botleft);
  
      gold_t= new Txt(0,ts*1);
      gold= new Gold(40,gold_t);

      creeps_t= new Txt(6*ts,0);
      creeps= new Creeps(route,creeps_t,gold);
      creeps.spawn_wave();
           
      time= new Txt();
      clock= new Clock(1000,time,creeps);
      
      towers= new TowerGrid(creeps);
      var b1= new TowerButton(towers, new BasicTower(),gold);
      var b2= new TowerButton(towers, new LongRangeTower(),gold,1);
   
    }
}
