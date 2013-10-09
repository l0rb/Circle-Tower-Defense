import flash.display.MovieClip;
import flash.display.Shape;
import flash.display.Graphics;
import flash.display.Sprite;

import flash.events.MouseEvent;
import flash.events.Event;

import Math;
import haxe.Timer;

// ========== SETTINGS ========== //

class Settings {

	static inline private var size= 2;

	static inline public var fontsize_small= 8*size;
	static inline public var fontsize_std= 12*size;
	static inline public var fontsize_big= 22*size;

	static inline public var text_box_bgcolor= 0xdcdcdc;
	static inline public var button_bgcolor= 0xdcdcdc;
	static inline public var button_bgcolor_on_hover= 0x50d0ff;

	static inline public var tilesize= 24;
   static inline public var creep_speedfactor= 2; // (tilesize/creep_speedfactor)%2==0 advisabe
	static inline public var wavetime= 12;
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

class TowerType {
   public var id:Int;
   public var range:Int;
   public var dmg:Int;
   public var cost:Int;
   public var color:Int;
   public var rate:Int; // time between shots in frames

   public function new() {
      id= 1;
      range= 50;
      dmg= 5;
      rate= 20;
      cost= 10;
      color= 0x0000aa;
   }
}

class Field extends Sprite {
   public var tower:TowerType;
   var frames:Int;
   var creeps:Creeps;

   public function new(x:Float, y:Float, c:Creeps) {
      super();
      creeps= c;
      var ts= Settings.tilesize;
      this.x= (x+0.5)*ts;
      this.y= (y+0.5)*ts;
      tower= null;
		graphics.lineStyle(1,0x000000);
		graphics.beginFill(0xffffff);
		graphics.drawCircle(0,0,3);
		graphics.endFill();
      
      this.addEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
      
      flash.Lib.current.addChild(this);
   }

   function fire() {
      // search for a creep in range
      var target= creeps.closest(x,y);
      if(target.distance<=tower.range) {
         target.creep.fire(tower.dmg);
      } 
   }

   function enter_frame(e:Event) {
      if(tower!=null) {
         frames+= 1;
         if(frames>=tower.rate) {
            fire();
            frames= 0;
         }
      }
   }

   public function build(t:TowerType,g:Gold) {
      tower= t;
      g.decrease(tower.cost);
		graphics.beginFill(0xffffff,0);
		graphics.drawCircle(0,0,tower.range);
		graphics.endFill();
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
         for(y in 0...height) {
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

   public function new(t:TowerGrid,type:TowerType,g:Gold) {
      super();
      y= Settings.tilesize*2.5;
      x= Settings.tilesize*11.5;
      towers= t;
      tower_type= type;
      gold= g;
		
      graphics.lineStyle(3,0xff0000);
		graphics.beginFill(0x00ffff);
		graphics.drawCircle(0,0,10);
		graphics.endFill();
      
      this.addEventListener(MouseEvent.MOUSE_DOWN,onclick);
      
      flash.Lib.current.addChild(this);
   }
         
   function onclick(e:MouseEvent) {
      clickSprite= new Sprite();
      var s= clickSprite;
      s.x= e.stageX;
      s.y= e.stageY;
		s.graphics.beginFill(0x000000,0.2);
		s.graphics.drawCircle(0,0,tower_type.range);
		s.graphics.beginFill(0xdd0000);
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
         flash.Lib.current.removeChild(s);
         towers.build(towers.get_field(s.x,s.y),tower_type,gold);
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
		   s.graphics.beginFill(0x00dd00);
	   	s.graphics.drawCircle(0,0,8);
		   s.graphics.endFill();
      } else {
		   s.graphics.beginFill(0xdd0000);
	   	s.graphics.drawCircle(0,0,8);
		   s.graphics.endFill();
      }
   }
   function can_build(x:Float, y:Float) {
      if(!gold.at_least(tower_type.cost)) { return false; }
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
   var speed:Float;
   var goal:RoutePoint;
   var route:Route;
   var frames:Int;
   var creeps:Creeps;
   var gold:Gold;

   public function new(r:Route,c:Creeps) {
      super();
      hp= 100;
      speed= 1;
      frames= 0;
      y= 0; // top of screen
      x= 5.5*Settings.tilesize;
      goal= new RoutePoint(x,2.5*Settings.tilesize);
      route= r;
      creeps= c;
      gold= c.gold;

		graphics.lineStyle(3,0xff0000);
		graphics.beginFill(0x0000ff);
		graphics.drawCircle(0,0,10);
		graphics.endFill();

      this.addEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
      
      flash.Lib.current.addChild(this);
   }

   function i_am_dead() {
      creeps.remove(this);
      flash.Lib.current.removeChild(this);
      creeps.update();
      gold.increase(1);
   }

   public function fire(dmg:Int) {
      i_am_dead();
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
         haxe.Timer.delay(callback(spawn,r),i);
         i+=waveival;
      }
   }
   
   public function spawn_wave() {
      spawn_wave_with_route(route);
   }
}

class Txt extends flash.text.TextField {
   public function new(x:Float=0,y:Float=0,text:String="") {
      super();
      this.text= text;
      this.x= x;
      this.y= y;

      flash.Lib.current.addChild(this);
   }
   public function update(t:String) {
      text= t;
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
      var b1= new TowerButton(towers, new TowerType(),gold);
   
   }

}
