import flash.display.MovieClip;
import flash.display.Shape;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.net.SharedObject;
import flash.events.MouseEvent;
import flash.events.Event;

import Math;
import haxe.Timer;

import Towers;
import Creeps;
import Interface;

import Settings;

class Stats {
   public var last_score:Int;
   public var total_score:Int;
   public var score_invested:Int; // score used to buy upgrades
         
   public function new() {
      // todo: read data from SharedObject
      last_score= 0;
      total_score= 0;
      score_invested= 0;
      load();
   }
   public function save() {
      var storage:SharedObject = SharedObject.getLocal("ctd_storage");
      storage.data.total_score= total_score;
      storage.data.total_score= score_invested;
      try {
         storage.flush(); // fails if user does not allow to save stuff local
      } catch(err:Dynamic) {
         trace("Error: can't save.");
      }
   }
   public function load() {
      var storage:SharedObject = SharedObject.getLocal("ctd_storage");
      if(storage.data.total_score) {
         total_score= storage.data.total_score;
         score_invested= storage.data.score_invested;
      }
   }
   public function add_score(s:Int=0) {
      last_score= s;
      total_score+= s;
      save();
   }
   public function invest(s:Int=0) {
      if(score_invested+s <= total_score) {
         score_invested+= s;
         save();
         return true;
      } else {
         return false;
      }
   }
}

class Upgrade {
   var affects:Array<Int>; // ids of all towers that benefit from this upgrade
   var base_cost:Int;
   var cost_increase_factor:Float;
   public var level:Int;
   public var name:String;
   public var desc:String;

   public function new(a:Array<Int>,n:String,d:String,c=100,cif=2.0) {
      level= 0;
      affects= a;
      name= n;
      desc= d;
      base_cost= c;
      cost_increase_factor= cif;
   }

   public function cost() {
      return Std.int( base_cost*Math.pow(cost_increase_factor,level) );
   }
   public function applies (t:TowerType) {
      return Lambda.has(affects, t.id);
   }
   public function apply (t:TowerType) {} // override with what upgrade actually is good for
}

class RangeUpgrade extends Upgrade {
   public function new() {
      super([1,2],"Range","Improve range of all towers.",120,1.66667);
   }
   override public function apply(t:TowerType) {
      t.base_range+= level; // increases range by 1 per level
   }
}

class DmgUpgrade1 extends Upgrade {
   public function new() {
      super([1],"Base Attack","Improve damage of basic tower.",100,1.5);
   }
   override public function apply(t:TowerType) {
      t.base_dmg+= level*2; // increases base_damage by 2 per level
   }
}

class UpgradeButton extends Button {
   public var upgrade:Upgrade;
   var nme:Txt;
   var desc:Txt;

   public function new(x:Int,y:Int,u:Upgrade) {
      super(x,y,"Level up!");
      this.x+= 200; // move button to right of text
      upgrade= u;
      nme= new Txt(x,y,upgrade.name+" Level "+Std.string(upgrade.level+1));
      desc= new Txt(x,y+nme.line_height,upgrade.desc+" Cost: "+Std.string(u.cost()),Settings.fontsize_small);
   }
   override public function hide() {
      flash.Lib.current.removeChild(this);
      desc.hide();
      nme.hide();
   }
   override public function show() {
      flash.Lib.current.addChild(this);
      desc.show();
      nme.show();
   }
   override function onclick(e:MouseEvent) {
      upgrade.level+=1;
      nme.update(upgrade.name+" Level "+Std.string(upgrade.level+1));
      desc.update(upgrade.desc+" Cost: "+Std.string(upgrade.cost()));
   }
}

class Upgrades extends List<UpgradeButton> {
   var points:Int;
   var menu:Menu;
   var back:Button;

   public function new(m:Menu) {
      super();
      menu=m;
      points=menu.stats.total_score;

      add(new UpgradeButton(10,10,new RangeUpgrade()));
      add(new UpgradeButton(10,40,new DmgUpgrade1()));

      back= new Button(10,150,"Back to Menu");
      back.addEventListener(MouseEvent.MOUSE_DOWN,click_back);
      hide();
   }

   function click_back(e:MouseEvent) {
      hide();
      menu.start();
   }
   public function hide() {
      back.hide();
      for(i  in iterator()) {
         i.hide();
      }
   }
   public function show() {
      back.show();
      for(i in iterator()) {
         i.show();
      }
   }
}

class Gold {
   private var amount:Int;
   var text:Txt;
      
   public function new(t:Txt) {
      amount= Settings.start_gold;
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
   public function stop() {
      text.hide();
   }
   public function start() {
      amount= Settings.start_gold;
      text.update("Gold: "+Std.string(amount));
      text.show();
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
      target.fire(source.dmg());
      haxe.Timer.delay(endExplosion,110);
   }

   public function endExplosion() {
      source.bullets.remove(this);
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
   public var bullets:List<Bullet>;
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
      bullets= new List<Bullet>();      

      this.addEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
      this.addEventListener(MouseEvent.MOUSE_OVER,mouse_over);
      this.addEventListener(MouseEvent.MOUSE_OUT,mouse_out);
      this.addEventListener(MouseEvent.MOUSE_DOWN,upgrade);
       
      flash.Lib.current.addChild(this);
   }
     
   public function delete() {
      hide();
   }
   public function hide() {
      if(!bullets.isEmpty()) {
         for(b in bullets.iterator()) {
            if(flash.Lib.current.contains(b)) {
               flash.Lib.current.removeChild(b);
            }
         }
      }
      flash.Lib.current.removeChild(this);
   }
   public function show() {
      flash.Lib.current.addChild(this);
   }
   public function reset() {
      tower= null;
      level= 0;
      graphics.clear();
      graphics.lineStyle(1,0x000000);
      graphics.beginFill(0xffffff);
      graphics.drawCircle(0,0,3);
      graphics.endFill();
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
         bullets.add(new Bullet(this, target.creep));
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
   public function delete() {
      for(f in iterator()) {
         f.delete();
         f= null;
      }
   }
   public function stop() {
      for(f in iterator()) {
         f.reset();
         f.hide();
      }
   }
   public function start() {
      for(f in iterator()) {
         f.show();
      }
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
      graphics.beginFill(type.color);
      graphics.drawCircle(0,0,10);
      graphics.endFill();
      
      this.addEventListener(MouseEvent.MOUSE_DOWN,onclick);
      this.addEventListener(MouseEvent.MOUSE_OVER,mouse_over);
      this.addEventListener(MouseEvent.MOUSE_OUT,mouse_out);
      
      flash.Lib.current.addChild(this);
   }
   
   public function hide() {
      flash.Lib.current.removeChild(this);
   }
   public function show() {
      flash.Lib.current.addChild(this);
   }
   public function delete() {
      hide();
   }
   public function set_type(t:TowerType) {
      tower_type= t;
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

class Creeps extends List<Creep> {
   var route:Route;
   var creep_text:Txt;
   var wave_text:Txt;
   var timer:List<Timer>;
   public var wave_counter:Int;
   public var killed:Int;
   public var gold:Gold;

   public function new(r:Route,ct:Txt,wt:Txt,g:Gold) {
      super();
      route= r;
      creep_text= ct;
      wave_text= wt;
      gold= g;
      wave_counter= 0;
      killed= 0;
      creep_text.update("Creeps: "+Std.string(length));
      wave_text.update("Wave: "+Std.string(wave_counter));
      timer= new List<Timer>();
      
      // can't add eventlistener to a List<T>
      // todo: find something better to attach eventlistener to
      flash.Lib.current.addEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
   }

   /*
   public function delete() {
      creep_text.delete();
      wave_text.delete();
      flash.Lib.current.removeEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
      for(s in timer.iterator()) {
         s.stop();
      }
      for(f in iterator()) {
         f.delete();
         f= null;
      }
   }
   */
   public function stop() {
      wave_counter= 0;
      killed= 0;
      creep_text.hide();
      wave_text.hide();
      flash.Lib.current.removeEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
      for(s in timer.iterator()) {
         s.stop();
      }
      for(f in iterator()) {
         f.delete();
      }
      clear(); // emtpy list
   }
   public function start() {
      creep_text.show();
      creep_text.update("Creeps: "+Std.string(length));
      wave_text.show();
      wave_text.update("Wave: "+Std.string(wave_counter));
      timer= new List<Timer>();
      flash.Lib.current.addEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
   }

   function enter_frame(e:Event) {
      remove_dead();
   }
   function remove_dead() {
      for(creep in iterator()) {
         if(creep.dead) {
            killed+= 1;
            gold.increase(creep.value);
            remove(creep);
            update();
            flash.Lib.current.removeChild(creep);
         }
      }
   }

   public function update() {
      creep_text.update("Creeps: "+Std.string(length));
      wave_text.update("Wave: "+Std.string(wave_counter));
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
      add(new Creep(r,50+10*wave_counter,wave_counter));
      update();
   }
   public function spawn_wave_with_route(r:Route) {
      wave_counter+= 1;
      var wavesize= Settings.wavesize;    // number of creeps
      var waveival= Settings.spawntime;  // time between creeps in ms
      var tmp=wavesize*waveival;
      var i=0;
      while(i<tmp) {
#if haxe3
         timer.add(haxe.Timer.delay(spawn.bind(r),i));
#else
         timer.add(haxe.Timer.delay(callback(spawn,r),i));
#end
         i+=waveival;
      }
   }
   
   public function spawn_wave() {
      spawn_wave_with_route(route);
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
   var t:Int;
   var text:Txt;
   var timer:Timer;
   var creeps:Creeps;

   public function new(t:Int,textField:Txt,c:Creeps) {
      n= Settings.wavetime;
      text= textField;
      text.update("Next Wave: "+Std.string(n));
      this.t= t;
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
      
   public function stop() {
      text.hide();
      timer.stop();
   }
   public function start() {
      n= Settings.wavetime;
      text.show();
      text.update("Next Wave: "+Std.string(n));
      timer= new Timer(t);
      timer.run= run;
   }
}

class Game {
   var creeps:Creeps;
   var route:Route;
   var clock:Clock;
   var gold:Gold;
   var towers:TowerGrid;
   var b1:TowerButton;
   var b2:TowerButton;
   var menu:Menu;
   var gameover:GameOver;
   var stats:Stats;
   var tower_types:Array<TowerType>;
   var upgrades:Upgrades;

   // textfields
   static var time:Txt;
   static var gold_t:Txt;
   static var creeps_t:Txt;
   static var wave_t:Txt;

   public function new(m:Menu,u:Upgrades) {
      menu= m;
      upgrades= u;
      stats= menu.stats;

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
      gold= new Gold(gold_t);

      creeps_t= new Txt(6*ts,0);
      wave_t= new Txt(6*ts,1*ts);
      creeps= new Creeps(route,creeps_t,wave_t,gold);
           
      time= new Txt();
      clock= new Clock(1000,time,creeps);
      
      tower_types= new Array<TowerType>();
      create_tower_types();
      towers= new TowerGrid(creeps);
      b1= new TowerButton(towers, tower_types[0],gold);
      b2= new TowerButton(towers, tower_types[1],gold,1);
  
      gameover= new GameOver(m);

      // can't add eventlistener to Game-Object
      // todo: find something better to attach eventlistener to
      // todo: have the spawn function dispatch a custom event to be listened for here
      flash.Lib.current.addEventListener(flash.events.Event.ENTER_FRAME,enter_frame);
      stop();
   }
   function create_tower_types() {
      if(tower_types.length!=0) { tower_types= []; }
      tower_types.push(new BasicTower());
      tower_types.push(new LongRangeTower());
      for(t in tower_types.iterator()) {
         for(u in upgrades.iterator()) {
            if(u.upgrade.applies(t)) {
               u.upgrade.apply(t);
            }
         }
      }
   }
   function enter_frame(e:Event) {
      is_it_over_yet();
   }
   function is_it_over_yet() {
      if(creeps.length>=Settings.death) {
         // yes it's over
         var score= gold.get()+creeps.killed*(10+creeps.wave_counter);
         stats.add_score(score);
         stop();
         gameover.start();
      }
   }
   public function stop() {
      towers.stop();
      creeps.stop();
      clock.stop();
      b1.hide();
      b2.hide();
      gold.stop();
   }
   public function start() {
      creeps.start();
      creeps.spawn_wave();
      clock.start();
      gold.start();
      b1.show();
      b2.show();
      towers.start();
      
      // so upgrades are applied
      create_tower_types();
      b1.set_type(tower_types[0]);
      b2.set_type(tower_types[1]);
   }
}

class GameOver {
   var menu:Menu;
   var done:Button;
   var stats:Stats;
   var score:Txt;

   public function new(m:Menu) {
      menu= m;
      stats= menu.stats;

      score= new Txt(10,10,"Your score: "+Std.string(stats.last_score));
      score.addline("All time Total: "+Std.string(stats.total_score));
 
      done= new Button(10,150,"Back to Menu");
      done.addEventListener(MouseEvent.MOUSE_DOWN,click_back);
      stop();
   }
   function click_back(e:MouseEvent) {
      stop();
      menu.start();
   }
   function stop() {
      score.hide();
      done.hide();
   }
   public function start() {
      score.update("Your score: "+Std.string(stats.last_score));
      score.update("All time Total: "+Std.string(stats.total_score),1);
      score.show();
      done.show();
   }
}

class Credits {
   var back:Button;
   var cred:Txt;
   var menu:Menu;

   public function new(m:Menu) {
      menu= m;

      cred= new Txt(10,10,"lorb");
      cred.addline("balrok");
      cred.addline("wyzau");
         
      back= new Button(10,150,"Back to Menu");
      back.addEventListener(MouseEvent.MOUSE_DOWN,click_back);
      hide();
   }
   function click_back(e:MouseEvent) {
      hide();
      menu.start();
   }
   public function hide() {
      cred.hide();
      back.hide();
   }
   public function show() {
      cred.show();
      back.show();
   }
}

class Menu {
   var game:Game;
   var cred:Credits;
   var up:Upgrades;
   var gameb:Button;
   var credb:Button;
   var upb:Button;
   public var stats:Stats; // public so all the submenus can access the stats through menu

   public function new() {
      gameb= new Button(120,40,"Start Game!");
      gameb.addEventListener(MouseEvent.MOUSE_DOWN,click_start);
      
      upb= new Button(120,70,"Upgrades");
      upb.addEventListener(MouseEvent.MOUSE_DOWN,click_upgrades);
            
      credb= new Button(120,100,"Credits");
      credb.addEventListener(MouseEvent.MOUSE_DOWN,click_credits);
          
      stats= new Stats();
      cred= new Credits(this);
      up= new Upgrades(this);
      game= new Game(this,up);
   }

   function click_start(e:MouseEvent) {
      stop();
      game.start();
   }
   function click_credits(e:MouseEvent) {
      stop();
      cred.show();
   }
   function click_upgrades(e:MouseEvent) {
      stop();
      up.show();
   }

   public function stop() {
      gameb.hide();
      credb.hide();
      upb.hide();
   }
   public function start() {
      gameb.show();
      credb.show();
      upb.show();
   }
}

class Test {
   static function main() {
      new Menu();
   }
}

