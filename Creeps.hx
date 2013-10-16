import flash.display.Shape;
import Settings;

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

class Creep extends Shape {
   var hp:Int;
   var maxhp:Int;
   var speed:Int;
   var goal:RoutePoint;
   var route:Route;
   var frames:Int;
   public var dead:Bool;
   public var value:Int;

   public function new(r:Route,mhp=50,val=1,s=1) {
      super();
      maxhp= mhp;
      hp= maxhp;
      speed= s;
      value= val;
      frames= 0;
      route= r;
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

   public function delete() {
      flash.Lib.current.removeChild(this);
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

   public function fire(dmg:Int) {
      hp -= dmg;
      if (hp <= 0) {
         this.dead= true;
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

