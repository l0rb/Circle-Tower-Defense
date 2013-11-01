import Math;

class TowerType {
   public var id:Int;
   public var base_range:Int;
   public var base_dmg:Int;
   public var base_cost:Int;
   public var color:Int;
   public var base_rate:Int; // time between shots in frames
   public var name:String;

   public function new(id=1,range=50,dmg=15,rate=20,cost=5,col=0x0000aa,n="[Tower]") {
      this.id= id;
      base_range= range;
      base_dmg= dmg;
      base_rate= rate;
      base_cost= cost;
      color= col;
      name= n;
   }
   public function dmg(l=0) {
      return base_dmg*(l+1);
   }
   public function range(l=0) {
      return base_range + 4*l;
   }
   public function rate(l=0) {
      return base_rate;
   }
   public function cost(l=0) {
      return Std.int( base_cost * Math.pow(2,l) );
   }
}

class BasicTower extends TowerType {
   public function new() {
      super(1,50,15,20,5,0x0000a0,"Basic Tower");
   }
}

class LongRangeTower extends TowerType {
   public function new() {
      super(2,80,10,20,10,0x00a0a0,"Long Range");
   }
}
