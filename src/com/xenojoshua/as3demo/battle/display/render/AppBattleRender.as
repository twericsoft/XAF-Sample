package com.xenojoshua.as3demo.battle.display.render
{
	import com.greensock.TweenLite;
	import com.greensock.plugins.AutoAlphaPlugin;
	import com.greensock.plugins.TweenPlugin;
	import com.xenojoshua.af.utils.timer.XafTimerManager;
	import com.xenojoshua.as3demo.battle.display.layers.AppBattleGridManager;
	import com.xenojoshua.as3demo.battle.display.util.AppBattleUtil;
	import com.xenojoshua.as3demo.battle.logic.AppBattleProcessor;
	import com.xenojoshua.as3demo.mvc.event.battle.AppBattleAnimeStartEvent;
	import com.xenojoshua.as3demo.mvc.model.enum.battle.AppSoldierAnimeName;
	import com.xenojoshua.as3demo.mvc.model.vo.battle.AppBattleSoldier;
	import com.xenojoshua.as3demo.mvc.view.battle.AppBattleMediator;
	import com.xenojoshua.as3demo.mvc.view.battle.soldier.AppBattleSoldierView;
	
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.events.Event;
	
	import org.osflash.signals.Signal;

	public class AppBattleRender
	{
		private static var _instance:AppBattleRender;
		
		/**
		 * Get instance of AppBattleRender.
		 * @return AppBattleRender _instance
		 */
		public static function get instance():AppBattleRender {
			if (!AppBattleRender._instance) {
				AppBattleRender._instance = new AppBattleRender();
			}
			return AppBattleRender._instance;
		}
		
		/**
		 * Initialize AppBattleRender.
		 * @return void
		 */
		public function AppBattleRender() {
			this._atkSoldiers = new Object();
			this._defSoldiers = new Object();
			this._playList = new Array();
			this._playListParams = new Array();
			this._playListDelay = new Array();
			this._playingCount = 0;
			this._playDelay = 0;
			this._currentQueueIndex = 0;
		}
		
		/**
		 * Destory the render.
		 * @return void
		 */
		public function dispose():void {
			this._atkSoldiers = {};
			this._defSoldiers = {};
			this._playList = [];
			this._playListParams = [];
			this._playListDelay = [];
			this._playingCount = 0;
			this._playDelay = 0;
			this._currentQueueIndex = 0;
		}
		
		private var DELAY_TIMER_NAME:String = 'AppBattleRenderDelayTimer';
		
		private var _atkSoldiers:Object; // <gridId:int, view:AppBattleSoldierView>
		private var _defSoldiers:Object; // <gridId:int, view:AppBattleSoldierView>
		
		/**
		 * this._playList:Array = [
		 *     [AppBattleRender.instance.playStand, AppBattleRender.instance.playAttack], // these two animes will be played first (one by one)
		 *     [AppBattleRender.instance.playHurt] // then after two animes above finished, this anime will be played
		 * ];
		 * this._playListParams:Array = [
		 *     [[soldier], [soldier, target]], // parameter array of the two animes with index 0
		 *     [[soldier]]
		 * ];
		 * this._playListDelay:Array = [
		 *     1000, // delay between index 0 animes and index 1 animes (delay: how many milliseconds after the animes of index 0 finished)
		 *     0
		 * ];
		 */
		private var _playList:Array;       // <index:int, animeFuncArr:Array>
		private var _playListParams:Array; // <index:int, animeFuncParamsArr:Array>
		private var _playListDelay:Array;  // <index:int, animeFuncDelay:Array>
		
		// STATUS
		private var _playingCount:int;
		private var _playDelay:int;
		private var _currentQueueIndex:int;
		
		//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
		//-* DATA INITIALIZATION
		//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
		/**
		 * Register battle soldier views.
		 * @param Array attackers 'AppBattleSoldierInfo'
		 * @param Array defenders 'AppBattleSoldierInfo'
		 * @return AppBattleRender render
		 */
		public function registerBattleSoldierView(attackers:Array, defenders:Array):AppBattleRender {
			for each (var atkSoldier:AppBattleSoldier in attackers) {
				var atkSoldierView:AppBattleSoldierView = new AppBattleSoldierView();
				var atkGrid:DisplayObjectContainer = AppBattleGridManager.instance.getAtkGrid(atkSoldier.gridId);
				atkGrid.addChild(atkSoldierView);
				this._atkSoldiers[atkSoldier.gridId] = atkSoldierView;
			}
			for each (var defSoldier:AppBattleSoldier in defenders) {
				var defSoldierView:AppBattleSoldierView = new AppBattleSoldierView();
				var defGrid:DisplayObjectContainer = AppBattleGridManager.instance.getDefGrid(defSoldier.gridId);
				defGrid.addChild(defSoldierView);
				this._defSoldiers[defSoldier.gridId] = defSoldierView;
			}
			return this;
		}
		
		//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
		//-* ANIME QUEUE
		//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
		/**
		 * Register an animation function into queue.
		 * @param int index
		 * @param Function animeFunc
		 * @param Array animeParams
		 * @param int animeDelay
		 * @return AppBattleRender render
		 */
		public function registerAnimeInQueue(index:int, animeFunc:Function, animeParams:Array, animeDelay:int):AppBattleRender {
			if (this._playList.hasOwnProperty(index)) {
				this._playList[index]       = new Array();
				this._playListParams[index] = new Array();
				this._playListDelay[index]  = 0;
			}
			
			this._playList[index].push(animeFunc);
			this._playListParams[index].push(animeParams);
			if (animeDelay > this._playListDelay[index]) {
				this._playListDelay[index] = animeDelay;
			}
			
			return this;
		}
		
		public function playQueue():void {
			this.removeQueueDelay(); // no matter delay timer exists or not, call remove first
			var isAnyAnimeInQueue:Boolean = false; // mark no anime left first

			for (var index:String in this._playList) {
				isAnyAnimeInQueue = true; // has anime left to play
				this._currentQueueIndex = Number(index);
				
				var queue:Array = this._playList[index];
				var queueParams:Array = this._playListParams[index];
				var queueDelay:int = this._playListDelay[index];
				// loop current index of queue, play all the animes
				for (var queuePos:String in queue) {
					var animeFunc:Function = queue[queuePos];
					var animeFuncParams:Array = queueParams[queuePos];
					animeFunc.apply(null, animeFuncParams); // play the anmie
					++this._playingCount;
				}
				if (queueDelay > 0) {
					this._playDelay = queueDelay;
				}
			}
			
			if (!isAnyAnimeInQueue) {
				AppBattleProcessor.instance.loop();
			}
		}
		
		/**
		 * Called when one anime ends.
		 * @return void
		 */
		private function onSingleAnimeEnd():void {
			--this._playingCount;
			if (this._playingCount <= 0) { // all animes of this loop has been finished
				// reset playing count
				this._playingCount = 0;
				// remove finished queue loop
				delete this._playList[this._currentQueueIndex];
				delete this._playListParams[this._currentQueueIndex];
				delete this._playListDelay[this._currentQueueIndex];
				this._currentQueueIndex = 0;
				// check delay
				if (this._playDelay) { // means need to delay, then play the next loop of anime queue
					// reset delay time
					this._playDelay = 0;
					this.setQueueDelay();
				} else  {
					this.playQueue();
				}
			}
		}
		
		/**
		 * Set queue play delay timer.
		 * @return void
		 */
		private function setQueueDelay():void {
			XafTimerManager.instance.registerTimer(this.DELAY_TIMER_NAME, this._playDelay, this.playQueue, 1);
		}
		
		/**
		 * Remove registered queue play delay timer.
		 * @return void
		 */
		private function removeQueueDelay():void {
			XafTimerManager.instance.removeTimer(this.DELAY_TIMER_NAME);
		}
		
		//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
		//-* ANIME FUNCTIONS
		//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
		/**
		 * Play soldier stand anime.
		 * This anime will call anime end at the beginning when it's playing.
		 * @param AppBattleSoldier soldier
		 * @return void
		 */
		public function playStand(soldier:AppBattleSoldier):void {
			var view:AppBattleSoldierView = this.getSoldierView(soldier);
			view.removeRoleLayer();
			
			var movie:MovieClip = AppBattleAnimeManager.instance.getRoleStand(soldier.roleId, soldier.isAttacker);
			view.addRoleMovie(movie);
			
			movie.gotoAndPlay(1);
			this.onSingleAnimeEnd();
		}
		
		/**
		 * Play soldier attack anime.
		 * @param AppBattleSoldier soldier
		 * @param AppBattleSoldier target
		 * @return void
		 */
		public function playAttack(soldier:AppBattleSoldier, target:AppBattleSoldier):void {
			var view:AppBattleSoldierView = this.getSoldierView(soldier);
			view.removeRoleLayer();
			
			var movie:MovieClip = AppBattleAnimeManager.instance.getRoleAttack(soldier.roleId, soldier.isAttacker);
			view.addRoleMovie(movie);
			movie.addEventListener(Event.ENTER_FRAME, attackEnd);
			var attackEnd:Function = function(e:Event):void {
				var display:MovieClip = e.target as MovieClip;
				if (display.currentFrame == display.totalFrames) {
					display.removeEventListener(Event.ENTER_FRAME, attackEnd);
				}
				this.playStand();
				this.onSingleAnimeEnd();
			};
			movie.gotoAndPlay(1);
		}
		
		/**
		 * Play soldier skill anime.
		 * @param AppBattleSoldier soldier
		 * @return void
		 */
		public function playSkill(soldier:AppBattleSoldier):void {
			var view:AppBattleSoldierView = this.getSoldierView(soldier);
			view.removeRoleLayer();
			
			var movie:MovieClip = AppBattleAnimeManager.instance.getRoleSkill(soldier.roleId, soldier.isAttacker);
			view.addRoleMovie(movie);
			movie.addEventListener(Event.ENTER_FRAME, skillEnd);
			var skillEnd:Function = function(e:Event):void {
				var display:MovieClip = e.target as MovieClip;
				if (display.currentFrame == display.totalFrames) {
					display.removeEventListener(Event.ENTER_FRAME, skillEnd);
				}
				this.playStand();
				this.onSingleAnimeEnd();
			};
			movie.gotoAndPlay(1);
		}
		
		/**
		 * Play soldier hurt anime.
		 * @param AppBattleSoldier soldier
		 * @return void
		 */
		public function playHurt(soldier:AppBattleSoldier):void {
			var view:AppBattleSoldierView = this.getSoldierView(soldier);
			view.removeRoleLayer();
			
			var movie:MovieClip = AppBattleAnimeManager.instance.getRoleHit(soldier.roleId, soldier.isAttacker);
			view.addRoleMovie(movie);
			movie.addEventListener(Event.ENTER_FRAME, hurtEnd);
			var hurtEnd:Function = function(e:Event):void {
				var display:MovieClip = e.target as MovieClip;
				if (display.currentFrame == display.totalFrames) {
					display.removeEventListener(Event.ENTER_FRAME, hurtEnd);
				}
				this.playStand();
				this.onSingleAnimeEnd();
			};
			movie.gotoAndPlay(1);
		}
		
		/**
		 * Play attack effect on defender (attack hurt recipient).
		 * @param AppBattleSoldier attacker attack caster
		 * @param AppBattleSoldier defender attack recipient
		 * @return void
		 */
		public function playAttackEffect(attacker:AppBattleSoldier, defender:AppBattleSoldier):void {
			var view:AppBattleSoldierView = this.getSoldierView(defender);
			view.removeEffectLayer();
			
			var movie:MovieClip = AppBattleAnimeManager.instance.getAttackEffect(
				attacker.isMagic ? AppBattleAnimeManager.ATTACK_TYPE_MGK : AppBattleAnimeManager.ATTACK_TYPE_PHY,
				defender.isAttacker
			);
			view.addEffectMovie(movie);
			movie.addEventListener(Event.ENTER_FRAME, effectEnd);
			var effectEnd:Function = function(e:Event):void {
				var display:MovieClip = e.target as MovieClip;
				if (display.currentFrame == display.totalFrames) {
					display.removeEventListener(Event.ENTER_FRAME, effectEnd);
				}
				view.removeEffectLayer();
				this.onSingleAnimeEnd();
			};
			movie.gotoAndPlay(1);
		}
		
		/**
		 * Play skill effect on defender (skill hurt recipient).
		 * @param AppBattleSoldier attacker skill caster
		 * @param AppBattleSoldier defender skill recipient
		 * @return void
		 */
		public function playSkillEffect(attacker:AppBattleSoldier, defender:AppBattleSoldier):void {
			var view:AppBattleSoldierView = this.getSoldierView(defender);
			view.removeEffectLayer();
			
			var movie:MovieClip = AppBattleAnimeManager.instance.getSkillEffect(attacker.skillId, defender.isAttacker);
			view.addEffectMovie(movie);
			movie.addEventListener(Event.ENTER_FRAME, effectEnd);
			var effectEnd:Function = function(e:Event):void {
				var display:MovieClip = e.target as MovieClip;
				if (display.currentFrame == display.totalFrames) {
					display.removeEventListener(Event.ENTER_FRAME, effectEnd);
				}
				view.removeEffectLayer();
				this.onSingleAnimeEnd();
			};
			movie.gotoAndPlay(1);
		}
		
		/**
		 * Play die anime.
		 * @param AppBattleSoldier soldier
		 * @return void
		 */
		public function playDie(soldier:AppBattleSoldier):void {
			var view:AppBattleSoldierView = this.getSoldierView(soldier);
			TweenPlugin.activate([AutoAlphaPlugin]);
			TweenLite.to(view.getRoleMovie(), 0.5, {
				autoAlpha: 0, onComplete: this.onDieEnd, onCompleteParams: [soldier, view]
			});
		}
		
		/**
		 * Callback when die anime ends.
		 * @param AppBattleSoldier soldier
		 * @param AppBattleSoldierView view
		 * @return void
		 */
		private function onDieEnd(soldier:AppBattleSoldier, view:AppBattleSoldierView):void {
			// dispose the view
			view.dispose();
			// remove manager handler
			if (soldier.isAttacker) {
				delete this._atkSoldiers[soldier.gridId];
			} else {
				delete this._defSoldiers[soldier.gridId];
			}
			this.onSingleAnimeEnd();
		}
		
		/**
		 * Play role move anime.
		 * @param AppBattleSoldier attacker
		 * @param AppBattleSoldier defender
		 * @return void
		 */
		public function playMove(attacker:AppBattleSoldier, defender:AppBattleSoldier):void {
			var atkView:AppBattleSoldierView = this.getSoldierView(attacker);
			var atkMovie:MovieClip = atkView.getRoleMovie();
			
			var offsetX:Number = atkView.width / 2;
			var offsetY:Number = atkView.height / 2;
			
			// disapper
			var targetPosX:Number = 0;
			var targetPosY:Number = 0;
			if (attacker.isAttacker) { // means actor is attacker or not
				
			}
			// show
		}
		
		/**
		 * Get soldier view from manager.
		 * @param AppBattleSoldier soldier
		 * @return AppBattleSoldierView view
		 */
		private function getSoldierView(soldier:AppBattleSoldier):AppBattleSoldierView {
			var soldiers:Object = soldier.isAttacker ? this._atkSoldiers : this._defSoldiers;
			
			return soldiers[soldier.gridId];
		}
	}
}