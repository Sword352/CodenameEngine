package funkin.game;

import funkin.scripting.Script;
import flixel.util.FlxDestroyUtil;
#if desktop
import funkin.system.Discord.DiscordClient;
#end
import Section.SwagSection;
import funkin.system.Song.SwagSong;
import funkin.scripting.ScriptPack;
import WiggleEffect.WiggleEffectType;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.addons.effects.FlxTrailArea;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.atlas.FlxAtlas;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxCollision;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import haxe.Json;
import haxe.io.Path;
import lime.utils.Assets;
import openfl.display.BlendMode;
import openfl.display.StageQuality;
import openfl.filters.ShaderFilter;
import funkin.system.Conductor;
import funkin.system.Song;
import funkin.editors.ChartingState;
import funkin.debug.AnimationDebug;

import funkin.menus.*;
import funkin.scripting.events.*;

using StringTools;

class PlayState extends MusicBeatState
{
	public static var instance:PlayState = null;

	/**
	 * SONG METADATA
	 */
	public static var SONG:SwagSong;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;
	public static var fromMods:Bool = false;

	public var scripts:ScriptPack;
	public var halloweenLevel:Bool = false;

	public var stage:Stage;
	public var scrollSpeed:Float = 0;

	public var vocals:FlxSound;

	public var dad:Character;
	public var gf:Character;
	public var boyfriend:Character;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];

	public var strumLine:FlxSprite;
	public var curSection:Int = 0;

	public var camFollow:FlxObject;

	private static var prevCamFollow:FlxObject;

	public var strumLineNotes:FlxTypedGroup<Strum>;
	public var playerStrums:FlxTypedGroup<Strum>;
	public var cpuStrums:FlxTypedGroup<Strum>;

	public var muteVocalsOnMiss:Bool = true;

	public var camZooming:Bool = false;
	public var camZoomingInterval:Int = 4;
	public var curSong:String = "";
	public var curStage:String = "";

	public var gfSpeed:Int = 1;
	public var health:Float = 1;
	public var combo:Int = 0;

	public var comboBreaks:Bool = false;
	public var healthBarBG:FlxSprite;
	public var healthBar:FlxBar;

	public var generatedMusic:Bool = false;
	public var startingSong:Bool = false;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;

	
	public var songScore:Int = 0;
	public var misses:Int = 0;
	public var scoreTxt:FlxText;
	public var missesTxt:FlxText;
	public var accuracyTxt:FlxText;

	public static var campaignScore:Int = 0;

	public var defaultCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;

	public var inCutscene:Bool = false;

	#if desktop
	// Discord RPC variables
	public var storyDifficultyText:String = "";
	public var iconRPC:String = "";
	public var songLength:Float = 0;
	public var detailsText:String = "";
	public var detailsPausedText:String = "";
	#end

	override public function create()
	{
		instance = this;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		scripts = new ScriptPack("PlayState");
		scripts.setParent(this);

		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);

		// camGame.widescreen = true;

		persistentUpdate = true;
		persistentDraw = true;

		if (SONG == null)
			SONG = Song.loadFromJson('tutorial', 'normal');

		scrollSpeed = SONG.speed;

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		#if desktop
		// TODO: Scriptable custom RPC
		iconRPC = SONG.player2;

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode)
		{
			detailsText = "Story Mode: Week " + storyWeek;
		}
		else
		{
			detailsText = "Freeplay";
		}

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		
		// Updating Discord Rich Presence.
		DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconRPC);
		#end
		dad = new Character(100, 100, SONG.player2);


		if (dad != null && dad.isGF) {
			dad.setPosition(400, 130);
			gf = dad;
			dad.scrollFactor.set(0.95, 0.95);
		} else {
			var gfVersion = SONG.gf;
			if (gfVersion == null) gfVersion = "gf";
			gf = new Character(400, 130, gfVersion);
			gf.scrollFactor.set(0.95, 0.95);
		}

		var camPos:FlxPoint = new FlxPoint(dad.getGraphicMidpoint().x, dad.getGraphicMidpoint().y);


		boyfriend = new Character(770, 100, SONG.player1, true);


		if (SONG.stage == null || SONG.stage.trim() == "") SONG.stage = "stage";
		add(new Stage(SONG.stage));

		
		switch(SONG.song) {
			// case "":
				// ADD YOUR HARDCODED SCRIPTS HERE!
			default:
				var content = Paths.getFolderContent('charts/${SONG.song}/', false, true, !fromMods);
				for(file in content) {
					var ext = Path.extension(file).toLowerCase();
					if (Script.scriptExtensions.contains(ext)) {
						scripts.add(Script.create(file));
					}
				}
		}

		scripts.load();
		scripts.call("create");

		add(gf);

		add(dad);
		add(boyfriend);


		strumLine = new FlxSprite(0, 50).makeGraphic(FlxG.width, 10);
		strumLine.scrollFactor.set();

		strumLineNotes = new FlxTypedGroup<Strum>();
		add(strumLineNotes);

		playerStrums = new FlxTypedGroup<Strum>();
		cpuStrums = new FlxTypedGroup<Strum>();

		// startCountdown();

		generateSong(SONG.song);

		// add(strumLine);

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		} else {
			camFollow = new FlxObject(0, 0, 2, 2);
			camFollow.setPosition(camPos.x, camPos.y);
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0.04);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow.getPosition());

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		// TODO: cool healthbar
		healthBarBG = new FlxSprite(0, FlxG.height * 0.9).loadGraphic(Paths.image('healthBar'));
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		add(healthBarBG);

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this,
			'health', 0, 2);
		healthBar.scrollFactor.set();
		healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
		add(healthBar);


		iconP1 = new HealthIcon(boyfriend.getIcon(), true);
		iconP1.y = healthBar.y - (iconP1.height / 2);
		add(iconP1);

		iconP2 = new HealthIcon(dad.getIcon(), false);
		iconP2.y = healthBar.y - (iconP2.height / 2);
		add(iconP2);

		scoreTxt = new FlxText(healthBarBG.x + 50, healthBarBG.y + 30, Std.int(healthBarBG.width - 100), "", 20);
		missesTxt = new FlxText(healthBarBG.x + 50, healthBarBG.y + 30, Std.int(healthBarBG.width - 100), "", 20);
		accuracyTxt = new FlxText(healthBarBG.x + 50, healthBarBG.y + 30, Std.int(healthBarBG.width - 100), "Accuracy: TODO", 20);
		for(text in [scoreTxt, missesTxt, accuracyTxt]) {
			text.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE);
			text.borderStyle = OUTLINE;
			text.borderSize = 1;
			text.borderColor = 0xFF000000;
			text.scrollFactor.set();
			add(text);
		}
		scoreTxt.alignment = RIGHT;
		missesTxt.alignment = CENTER;
		accuracyTxt.alignment = LEFT;

		for(e in [strumLineNotes, notes, healthBar, healthBarBG, iconP1, iconP2, scoreTxt, missesTxt, accuracyTxt]) {
			e.cameras = [camHUD];
		}

		startingSong = true;

		super.create();
	}

	public override function createPost() {
		super.createPost();
		startCountdown();
		scripts.call("createPost");
	}

	public var startTimer:FlxTimer;
	public var perfectMode:Bool = false;
	public var introLength:Int = 5;

	function startCountdown():Void
	{

		inCutscene = false;

		generateStaticArrows(0);
		generateStaticArrows(1);
		scripts.call("onStartCountdown");

		startedCountdown = true;
		Conductor.songPosition = 0;
		Conductor.songPosition -= Conductor.crochet * introLength;

		var swagCounter:Int = 0;

		startTimer = new FlxTimer().start(Conductor.crochet / 1000, function(tmr:FlxTimer)
		{
			dad.dance();
			gf.dance();
			boyfriend.playAnim('idle');

			var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
			introAssets.set('default', ['ready', "set", "go"]);
			introAssets.set('school', ['weeb/pixelUI/ready-pixel', 'weeb/pixelUI/set-pixel', 'weeb/pixelUI/date-pixel']);
			introAssets.set('schoolEvil', ['weeb/pixelUI/ready-pixel', 'weeb/pixelUI/set-pixel', 'weeb/pixelUI/date-pixel']);

			var introAlts:Array<String> = introAssets.get('default');
			var altSuffix:String = "";

			for (value in introAssets.keys())
			{
				if (value == curStage)
				{
					introAlts = introAssets.get(value);
					altSuffix = '-pixel';
				}
			}

			// TODO: Cancelable countdown
			scripts.call("onCountdown", [swagCounter]);

			switch (swagCounter)

			{
				case 0:
					FlxG.sound.play(Paths.sound('intro3'), 0.6);
				case 1:
					var ready:FlxSprite = new FlxSprite().loadGraphic(Paths.image(introAlts[0]));
					ready.scrollFactor.set();
					ready.updateHitbox();

					if (curStage.startsWith('school'))
						ready.setGraphicSize(Std.int(ready.width * daPixelZoom));

					ready.screenCenter();
					add(ready);
					FlxTween.tween(ready, {y: ready.y += 100, alpha: 0}, Conductor.crochet / 1000, {
						ease: FlxEase.cubeInOut,
						onComplete: function(twn:FlxTween)
						{
							ready.destroy();
						}
					});
					FlxG.sound.play(Paths.sound('intro2'), 0.6);
				case 2:
					var set:FlxSprite = new FlxSprite().loadGraphic(Paths.image(introAlts[1]));
					set.scrollFactor.set();

					if (curStage.startsWith('school'))
						set.setGraphicSize(Std.int(set.width * daPixelZoom));

					set.screenCenter();
					add(set);
					FlxTween.tween(set, {y: set.y += 100, alpha: 0}, Conductor.crochet / 1000, {
						ease: FlxEase.cubeInOut,
						onComplete: function(twn:FlxTween)
						{
							set.destroy();
						}
					});
					FlxG.sound.play(Paths.sound('intro1'), 0.6);
				case 3:
					var go:FlxSprite = new FlxSprite().loadGraphic(Paths.image(introAlts[2]));
					go.scrollFactor.set();

					if (curStage.startsWith('school'))
						go.setGraphicSize(Std.int(go.width * daPixelZoom));

					go.updateHitbox();

					go.screenCenter();
					add(go);
					FlxTween.tween(go, {y: go.y += 100, alpha: 0}, Conductor.crochet / 1000, {
						ease: FlxEase.cubeInOut,
						onComplete: function(twn:FlxTween)
						{
							go.destroy();
						}
					});
					FlxG.sound.play(Paths.sound('introGo'), 0.6);
				case 4:
			}

			swagCounter += 1;
			// generateSong('fresh');
		}, introLength);
	}

	public var previousFrameTime:Int = 0;
	public var lastReportedPlayheadPosition:Int = 0;
	public var songTime:Float = 0;

	function startSong():Void
	{
		startingSong = false;

		previousFrameTime = FlxG.game.ticks;
		lastReportedPlayheadPosition = 0;

		if (!paused)
			FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 1, false);
		FlxG.sound.music.onComplete = endSong;
		vocals.play();

		updateDiscordStatus();
	}

	public override function destroy() {
		scripts.call("destroy");
		super.destroy();
		FlxDestroyUtil.destroy(scripts);
		instance = null;
	}

	public var debugNum:Int = 0;

	private function generateSong(dataPath:String):Void
	{
		// FlxG.log.add(ChartParser.parse());

		var songData = SONG;
		Conductor.changeBPM(songData.bpm);

		curSong = songData.song;

		if (SONG.needsVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
		else
			vocals = new FlxSound();

		FlxG.sound.list.add(vocals);

		notes = new FlxTypedGroup<Note>();
		add(notes);

		var noteData:Array<SwagSection>;

		// NEW SHIT
		noteData = songData.notes;

		var playerCounter:Int = 0;

		var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped
		for (section in noteData)
		{
			var coolSection:Int = Std.int(section.lengthInSteps / 4);

			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);

				var gottaHitNote:Bool = section.mustHitSection;

				if (songNotes[1] > 3)
				{
					gottaHitNote = !section.mustHitSection;
				}

				var oldNote:Note;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
				else
					oldNote = null;

				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
				swagNote.sustainLength = songNotes[2];
				swagNote.scrollFactor.set(0, 0);

				var susLength:Float = swagNote.sustainLength;

				susLength = susLength / Conductor.stepCrochet;
				unspawnNotes.push(swagNote);
				if (susLength > 0.75) susLength++;

				for (susNote in 0...Math.floor(susLength))
				{
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

					var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote), daNoteData, oldNote, true);
					sustainNote.scrollFactor.set();
					unspawnNotes.push(sustainNote);

					sustainNote.mustPress = gottaHitNote;

					if (sustainNote.mustPress)
					{
						sustainNote.x += FlxG.width / 2; // general offset
					}
				}

				swagNote.mustPress = gottaHitNote;

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else {}
			}
			daBeats += 1;
		}

		// trace(unspawnNotes.length);
		// playerCounter += 1;

		unspawnNotes.sort(sortByShit);

		generatedMusic = true;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	private function generateStaticArrows(player:Int):Void
	{
		for (i in 0...4)
		{
			// FlxG.log.add(i);
			var babyArrow:Strum = new Strum(0, strumLine.y);

			switch (curStage)
			{
				case 'school' | 'schoolEvil':
					babyArrow.loadGraphic(Paths.image('weeb/pixelUI/arrows-pixels'), true, 17, 17);
					babyArrow.animation.add('green', [6]);
					babyArrow.animation.add('red', [7]);
					babyArrow.animation.add('blue', [5]);
					babyArrow.animation.add('purplel', [4]);

					babyArrow.setGraphicSize(Std.int(babyArrow.width * daPixelZoom));
					babyArrow.updateHitbox();
					babyArrow.antialiasing = false;

					switch (Math.abs(i))
					{
						case 0:
							babyArrow.animation.add('static', [0]);
							babyArrow.animation.add('pressed', [4, 8], 12, false);
							babyArrow.animation.add('confirm', [12, 16], 24, false);
						case 1:
							babyArrow.animation.add('static', [1]);
							babyArrow.animation.add('pressed', [5, 9], 12, false);
							babyArrow.animation.add('confirm', [13, 17], 24, false);
						case 2:
							babyArrow.animation.add('static', [2]);
							babyArrow.animation.add('pressed', [6, 10], 12, false);
							babyArrow.animation.add('confirm', [14, 18], 12, false);
						case 3:
							babyArrow.animation.add('static', [3]);
							babyArrow.animation.add('pressed', [7, 11], 12, false);
							babyArrow.animation.add('confirm', [15, 19], 24, false);
					}

				default:
					babyArrow.frames = Paths.getSparrowAtlas('NOTE_assets');
					babyArrow.animation.addByPrefix('green', 'arrowUP');
					babyArrow.animation.addByPrefix('blue', 'arrowDOWN');
					babyArrow.animation.addByPrefix('purple', 'arrowLEFT');
					babyArrow.animation.addByPrefix('red', 'arrowRIGHT');

					babyArrow.antialiasing = true;
					babyArrow.setGraphicSize(Std.int(babyArrow.width * 0.7));

					switch (Math.abs(i))
					{
						case 0:
							babyArrow.animation.addByPrefix('static', 'arrowLEFT');
							babyArrow.animation.addByPrefix('pressed', 'left press', 24, false);
							babyArrow.animation.addByPrefix('confirm', 'left confirm', 24, false);
						case 1:
							babyArrow.animation.addByPrefix('static', 'arrowDOWN');
							babyArrow.animation.addByPrefix('pressed', 'down press', 24, false);
							babyArrow.animation.addByPrefix('confirm', 'down confirm', 24, false);
						case 2:
							babyArrow.animation.addByPrefix('static', 'arrowUP');
							babyArrow.animation.addByPrefix('pressed', 'up press', 24, false);
							babyArrow.animation.addByPrefix('confirm', 'up confirm', 24, false);
						case 3:
							babyArrow.animation.addByPrefix('static', 'arrowRIGHT');
							babyArrow.animation.addByPrefix('pressed', 'right press', 24, false);
							babyArrow.animation.addByPrefix('confirm', 'right confirm', 24, false);
					}
			}

			// babyArrow.x += Note.swagWidth * 1;
			babyArrow.x = (FlxG.width * 0.25) + (Note.swagWidth * (i - 2));
			babyArrow.updateHitbox();
			babyArrow.scrollFactor.set();

			if (!isStoryMode)
			{
				babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {y: babyArrow.y + 10, alpha: 1}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}

			babyArrow.ID = i;

			if (player == 1)
			{
				playerStrums.add(babyArrow);
			} else {
				babyArrow.cpu = true;
				cpuStrums.add(babyArrow);
			}

			babyArrow.animation.play('static');
			babyArrow.x += ((FlxG.width / 2) * player);

			strumLineNotes.add(babyArrow);
		}
	}

	function tweenCamIn():Void
	{
		FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut});
	}

	override function openSubState(SubState:FlxSubState)
	{
		// TODO: Cancellable substate opening.
		scripts.call("onSubstateOpen", [SubState]);
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
			}

			if (!startTimer.finished)
				startTimer.active = false;
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		scripts.call("onSubstateClose");
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong)
			{
				resyncVocals();
			}

			if (!startTimer.finished)
				startTimer.active = true;
			paused = false;

			#if desktop
			if (startTimer.finished)
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconRPC, true, songLength - Conductor.songPosition);
			}
			else
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconRPC);
			}
			#end
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		scripts.call("onFocus");
		#if desktop
		if (health > 0 && !paused)
		{
			if (Conductor.songPosition > 0.0)
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconRPC, true, songLength - Conductor.songPosition);
			}
			else
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconRPC);
			}
		}
		#end

		super.onFocus();
	}
	
	override public function onFocusLost():Void
	{
		scripts.call("onFocusLost");
		#if desktop
		if (health > 0 && !paused)
		{
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconRPC);
		}
		#end

		super.onFocusLost();
	}

	function resyncVocals():Void
	{
		vocals.pause();

		FlxG.sound.music.play();
		Conductor.songPosition = FlxG.sound.music.time;
		vocals.time = Conductor.songPosition;
		vocals.play();
		scripts.call("onVocalsResync");
	}

	public var paused:Bool = false;
	public var startedCountdown:Bool = false;
	public var canPause:Bool = true;


	public function pauseGame() {
		// TODO: Cancellable game pause
		scripts.call("onGamePause");
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		// 1 / 1000 chance for Gitaroo Man easter egg
		if (FlxG.random.bool(0.1))
		{
			// gitaroo man easter egg
			FlxG.switchState(new GitarooPause());
		}
		else
			openSubState(new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
	
		updateDiscordStatus();
	}

	// TODO: Update Discord Status
	public function updateDiscordStatus() {
		// TODO: Cancellable Discord Update Presence
		#if desktop
		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;

		// Updating Discord Rich Presence (with Time Left)
		DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconRPC, true, songLength);
		#end
		scripts.call("onDiscordPresenceUpdate");
	}
	override public function update(elapsed:Float)
	{
		#if !debug
		perfectMode = false;
		#end

		super.update(elapsed);
		scripts.call("update", [elapsed]);

		scoreTxt.text = 'Score:$songScore';
		missesTxt.text = '${comboBreaks ? "Combo Breaks" : "Misses"}:$misses';

		if (FlxG.keys.justPressed.ENTER && startedCountdown && canPause)
			pauseGame();

		if (FlxG.keys.justPressed.SEVEN)
		{
			FlxG.switchState(new ChartingState());

			#if desktop
			DiscordClient.changePresence("Chart Editor", null, null, true);
			#end
		}

		// FlxG.watch.addQuick('VOL', vocals.amplitudeLeft);
		// FlxG.watch.addQuick('VOLRight', vocals.amplitudeRight);

		// TODO: FPS-compatible lerping
		iconP1.scale.set(lerp(iconP1.scale.x, 1, 0.33), lerp(iconP1.scale.y, 1, 0.33));
		iconP2.scale.set(lerp(iconP2.scale.x, 1, 0.33), lerp(iconP2.scale.y, 1, 0.33));

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		var iconOffset:Int = 26;

		iconP1.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01) - iconOffset);
		iconP2.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) - (iconP2.width - iconOffset);

		if (health > 2)
			health = 2;

		iconP1.health = health / 2;
		iconP2.health = 1 - (health / 2);
		
		/* if (FlxG.keys.justPressed.NINE)
			FlxG.switchState(new Charting()); */

		if (FlxG.keys.justPressed.EIGHT)
			FlxG.switchState(new AnimationDebug(SONG.player2));

		if (startingSong)
		{
			if (startedCountdown)
			{
				Conductor.songPosition += FlxG.elapsed * 1000;
				if (Conductor.songPosition >= 0)
					startSong();
			}
		}
		else
		{
			// Conductor.songPosition = FlxG.sound.music.time;
			Conductor.songPosition += FlxG.elapsed * 1000;

			if (!paused)
			{
				songTime += FlxG.game.ticks - previousFrameTime;
				previousFrameTime = FlxG.game.ticks;

				// Interpolation type beat
				if (Conductor.lastSongPos != Conductor.songPosition)
				{
					songTime = (songTime + Conductor.songPosition) / 2;
					Conductor.lastSongPos = Conductor.songPosition;
					// Conductor.songPosition += FlxG.elapsed * 1000;
					// trace('MISSED FRAME');
				}
			}

			// Conductor.lastSongPos = FlxG.sound.music.time;
		}

		if (generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null)
		{
			if (PlayState.SONG.notes[Std.int(curStep / 16)].mustHitSection)
			{
				var pos = boyfriend.getCameraPosition();
				camFollow.setPosition(pos.x, pos.y);

				// switch (curStage)
				// {
				// 	case 'limo':
				// 		camFollow.x = boyfriend.getMidpoint().x - 300;
				// 	case 'mall':
				// 		camFollow.y = boyfriend.getMidpoint().y - 200;
				// 	case 'school':
				// 		camFollow.x = boyfriend.getMidpoint().x - 200;
				// 		camFollow.y = boyfriend.getMidpoint().y - 200;
				// 	case 'schoolEvil':
				// 		camFollow.x = boyfriend.getMidpoint().x - 200;
				// 		camFollow.y = boyfriend.getMidpoint().y - 200;
				// }
				
				if (SONG.song.toLowerCase() == 'tutorial')
				{
					FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut});
				}
			} else {
				var pos = dad.getCameraPosition();
				camFollow.setPosition(pos.x, pos.y);

				// camFollow.setPosition(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
				// camFollow.setPosition(lucky.getMidpoint().x - 120, lucky.getMidpoint().y + 210);

				// switch (dad.curCharacter)
				// {
				// 	case 'mom':
				// 		camFollow.y = dad.getMidpoint().y;
				// 	case 'senpai':
				// 		camFollow.y = dad.getMidpoint().y - 430;
				// 		camFollow.x = dad.getMidpoint().x - 100;
				// 	case 'senpai-angry':
				// 		camFollow.y = dad.getMidpoint().y - 430;
				// 		camFollow.x = dad.getMidpoint().x - 100;
				// }

				if (dad.curCharacter == 'mom')
					vocals.volume = 1;

				if (SONG.song.toLowerCase() == 'tutorial')
				{
					tweenCamIn();
				}
			}
		}

		if (camZooming)
		{
			FlxG.camera.zoom = lerp(FlxG.camera.zoom, defaultCamZoom, 0.05);
			camHUD.zoom = lerp(camHUD.zoom, 1, 0.05);
		}

		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		if (curSong == 'Fresh')
		{
			switch (curBeat)
			{
				case 16:
					camZooming = true;
					gfSpeed = 2;
				case 48:
					gfSpeed = 1;
				case 80:
					gfSpeed = 2;
				case 112:
					gfSpeed = 1;
				case 163:
					// FlxG.sound.music.stop();
					// FlxG.switchState(new TitleState());
			}
		}

		if (curSong == 'Bopeebo')
		{
			switch (curBeat)
			{
				case 128, 129, 130:
					vocals.volume = 0;
					// FlxG.sound.music.stop();
					// FlxG.switchState(new PlayState());
			}
		}
		// better streaming of shit

		// RESET = Quick Game Over Screen
		if (controls.RESET)
		{
			health = 0;
			trace("RESET = True");
		}

		// CHEAT = brandon's a pussy
		if (controls.CHEAT)
		{
			health += 1;
			trace("User is cheating!");
		}

		if (health <= 0)
		{
			boyfriend.stunned = true;

			persistentUpdate = false;
			persistentDraw = false;
			paused = true;

			vocals.stop();
			FlxG.sound.music.stop();

			openSubState(new GameOverSubstate(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

			// FlxG.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
			
			#if desktop
			// Game Over doesn't get his own variable because it's only used here
			DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconRPC);
			#end
		}

		while(unspawnNotes[0] != null && unspawnNotes[0].strumTime - Conductor.songPosition < 1500)
			notes.add(unspawnNotes.shift());
		

		if (generatedMusic)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				if (!daNote.mustPress && !daNote.wasGoodHit && daNote.strumTime <= Conductor.songPosition) goodNoteHit(daNote);
				// TODO: FIXED STEP CROCHET PER NOTES FOR BPM CHANGES
				if (daNote.wasGoodHit && daNote.isSustainNote && daNote.strumTime + (Conductor.stepCrochet) < Conductor.songPosition) {
					deleteNote(daNote);
					return;
				}
				if (daNote.tooLate) {
					noteMiss(daNote);
					return;
				}

				var strum:Strum = null;
				for(e in (daNote.mustPress ? playerStrums : cpuStrums).members) {
					if (e.ID == daNote.noteData % 4) {
						strum = e;
						break;
					}
				}
				if (strum == null) return;

				strum.updateNotePosition(daNote);
				strum.updateClipRect(daNote);
			});
		}

		if (!inCutscene)
			keyShit();

		#if debug
		if (FlxG.keys.justPressed.ONE)
			endSong();
		#end
		
		scripts.call("updatePost", [elapsed]);
	}

	function endSong():Void
	{
		scripts.call("onSongEnd");
		canPause = false;
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		if (SONG.validScore)
		{
			#if !switch
			Highscore.saveScore(SONG.song, songScore, storyDifficulty);
			#end
		}

		if (isStoryMode)
		{
			campaignScore += songScore;

			storyPlaylist.remove(storyPlaylist[0]);

			if (storyPlaylist.length <= 0)
			{
				FlxG.sound.playMusic(Paths.music('freakyMenu'));

				transIn = FlxTransitionableState.defaultTransIn;
				transOut = FlxTransitionableState.defaultTransOut;

				FlxG.switchState(new StoryMenuState());

				// if ()
				StoryMenuState.weekUnlocked[Std.int(Math.min(storyWeek + 1, StoryMenuState.weekUnlocked.length - 1))] = true;

				if (SONG.validScore)
				{
					Highscore.saveWeekScore(storyWeek, campaignScore, storyDifficulty);
				}

				FlxG.save.data.weekUnlocked = StoryMenuState.weekUnlocked;
				FlxG.save.flush();
			}
			else
			{
				// TODO: NOT INT DIFFICULTIES
				var difficulty:String = CoolUtil.difficultyString();

				trace('LOADING NEXT SONG');
				trace(PlayState.storyPlaylist[0].toLowerCase() + difficulty);

				if (SONG.song.toLowerCase() == 'eggnog')
				{
					var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
						-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
					blackShit.scrollFactor.set();
					add(blackShit);
					camHUD.visible = false;

					FlxG.sound.play(Paths.sound('Lights_Shut_off'));
				}

				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				prevCamFollow = camFollow;

				PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase(), difficulty);
				FlxG.sound.music.stop();

				FlxG.switchState(new PlayState());
			}
		}
		else
		{
			trace('WENT BACK TO FREEPLAY??');
			FlxG.switchState(new FreeplayState());
		}
	}

	public var endingSong:Bool = false;

	private function popUpScore(strumtime:Float):Void
	{
		var noteDiff:Float = Math.abs(strumtime - Conductor.songPosition);
		vocals.volume = 1;

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(0, 0, 0, placement, 32);
		coolText.screenCenter();
		coolText.x = FlxG.width * 0.55;
		//

		var rating:FlxSprite = new FlxSprite();
		var score:Int = 350;

		var daRating:String = "sick";

		if (noteDiff > Conductor.safeZoneOffset * 0.9)
		{
			daRating = 'shit';
			score = 50;
		}
		else if (noteDiff > Conductor.safeZoneOffset * 0.75)
		{
			daRating = 'bad';
			score = 100;
		}
		else if (noteDiff > Conductor.safeZoneOffset * 0.2)
		{
			daRating = 'good';
			score = 200;
		}

		songScore += score;

		/* if (combo > 60)
				daRating = 'sick';
			else if (combo > 12)
				daRating = 'good'
			else if (combo > 4)
				daRating = 'bad';
		 */

		var pixelShitPart1:String = "";
		var pixelShitPart2:String = '';

		if (curStage.startsWith('school'))
		{
			pixelShitPart1 = 'weeb/pixelUI/';
			pixelShitPart2 = '-pixel';
		}

		rating.loadGraphic(Paths.image(pixelShitPart1 + daRating + pixelShitPart2));
		rating.screenCenter();
		rating.x = coolText.x - 40;
		rating.y -= 60;
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'combo' + pixelShitPart2));
		comboSpr.screenCenter();
		comboSpr.x = coolText.x;
		comboSpr.acceleration.y = 600;
		comboSpr.velocity.y -= 150;

		comboSpr.velocity.x += FlxG.random.int(1, 10);
		add(rating);

		if (!curStage.startsWith('school'))
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			rating.antialiasing = true;
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
			comboSpr.antialiasing = true;
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.7));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.7));
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		var seperatedScore:Array<Int> = [];

		seperatedScore.push(Math.floor(combo / 100));
		seperatedScore.push(Math.floor((combo - (seperatedScore[0] * 100)) / 10));
		seperatedScore.push(combo % 10);

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'num' + Std.int(i) + pixelShitPart2));
			numScore.screenCenter();
			numScore.x = coolText.x + (43 * daLoop) - 90;
			numScore.y += 80;

			if (!curStage.startsWith('school'))
			{
				numScore.antialiasing = true;
				numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
			}
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y -= FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);

			if (combo >= 10 || combo == 0)
				add(numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002
			});

			daLoop++;
		}
		/* 
			trace(combo);
			trace(seperatedScore);
		 */

		coolText.text = Std.string(seperatedScore);
		// add(coolText);

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.crochet * 0.001
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {
			onComplete: function(tween:FlxTween)
			{
				coolText.destroy();
				comboSpr.destroy();

				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.001
		});

		curSection += 1;
	}

	private function keyShit():Void
	{
		// HOLDING
		var pressed = [controls.LEFT, controls.DOWN, controls.UP, controls.RIGHT];
		var justPressed = [controls.LEFT_P, controls.DOWN_P, controls.UP_P, controls.RIGHT_P];
		var justReleased = [controls.LEFT_R, controls.DOWN_R, controls.UP_R, controls.RIGHT_R];

		var event = scripts.event("onKeyShit", new InputSystemEvent([controls.LEFT, controls.DOWN, controls.UP, controls.RIGHT], [controls.LEFT_P, controls.DOWN_P, controls.UP_P, controls.RIGHT_P], [controls.LEFT_R, controls.DOWN_R, controls.UP_R, controls.RIGHT_R]));
		if (event.cancelled) return;
		justReleased = CoolUtil.getDefault(event.pressed, []);
		justReleased = CoolUtil.getDefault(event.justPressed, []);
		justReleased = CoolUtil.getDefault(event.justReleased, []);

		var funcsToExec:Array<Note->Void> = [];
		if (pressed.contains(true)) {
			funcsToExec.push(function(note:Note) {
				if (pressed[note.strumID] && note.isSustainNote && note.canBeHit && note.mustPress && !note.wasGoodHit) {
					goodNoteHit(note);
				}
			});
		}

		var notePerStrum = [for(i in 0...4) null];
		var additionalNotes:Array<Note> = [];
		if (justPressed.contains(true)) {
			funcsToExec.push(function(note:Note) {
				if (justPressed[note.strumID] && !note.isSustainNote && note.mustPress && !note.wasGoodHit && note.canBeHit) {
					if (notePerStrum[note.strumID] == null) 										notePerStrum[note.strumID] = note;
					else if (Math.abs(notePerStrum[note.strumID].strumTime - note.strumTime) <= 10) additionalNotes.push(note);
					else if (note.strumTime < notePerStrum[note.strumID].strumTime)					notePerStrum[note.strumID] = note;
				}
			});
		}

		notes.forEachAlive(function(note:Note) {
			for(e in funcsToExec) e(note);
		});

		for(e in notePerStrum) if (e != null) goodNoteHit(e);
		for(e in additionalNotes) goodNoteHit(e);

		playerStrums.forEach(function(str:Strum) {
			str.updatePlayerInput(pressed[str.ID], justPressed[str.ID], justReleased[str.ID]);
		});
		scripts.call("onKeyShitPost");
	}

	function noteMiss(note:Note):Void
	{
		if (!boyfriend.stunned)
		{
			health -= 0.04;
			if (combo > 5 && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
			}
			combo = 0;

			songScore -= 10;
			misses++;

			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
			// FlxG.sound.play(Paths.sound('missnote1'), 1, false);
			// FlxG.log.add('played imss note');

			if (muteVocalsOnMiss) vocals.volume = 0;
			boyfriend.stunned = true;

			switch (note.strumID)
			{
				case 0:
					boyfriend.playAnim('singLEFTmiss', true);
				case 1:
					boyfriend.playAnim('singDOWNmiss', true);
				case 2:
					boyfriend.playAnim('singUPmiss', true);
				case 3:
					boyfriend.playAnim('singRIGHTmiss', true);
			}
			deleteNote(note);
		}
	}

	public function getNoteType(id:Int) {
		// TODO: Note Types
		return null;
	}

	function goodNoteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			note.wasGoodHit = true;

			var event:NoteHitEvent;
			if (note.mustPress)
				event = scripts.event("onPlayerHit", new NoteHitEvent(note, boyfriend, true, note.noteType, note.strumID, note.noteData > 0 ? 0.023 : 0.004));
			else
				event = scripts.event("onDadHit", new NoteHitEvent(note, dad, false, note.noteType, note.strumID, 0));
			
			if (!event.cancelled) {
				if (event.player && !note.isSustainNote)
				{
					combo++;
					popUpScore(note.strumTime);
				}

				health += event.healthGain;
	
				if (!event.animCancelled) {
					event.character.playSingAnim(event.direction);
				}
	
				(event.player ? playerStrums : cpuStrums).forEach(function(str:Strum) {
					if (str.ID == Math.abs(note.strumID)) {
						str.press(note.strumTime);
					}
				});
			}

			if (event.unmuteVocals) vocals.volume = 1;
			if (event.enableCamZooming) camZooming = true;

			if (event.deleteNote && !note.isSustainNote) deleteNote(note);
		}
	}

	public function deleteNote(note:Note) {
		// TODO: See TODO above the TODO above the one that says TODO note pressed handler for dad
		scripts.call("onNoteDelete", [note]);
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	override function stepHit()
	{
		super.stepHit();
		scripts.call("stepHit", [curStep]);
		if (FlxG.sound.music.time > Conductor.songPosition + 20 || FlxG.sound.music.time < Conductor.songPosition - 20)
		{
			resyncVocals();
		}
	}

	public var lightningStrikeBeat:Int = 0;
	public var lightningOffset:Int = 8;

	override function beatHit()
	{
		super.beatHit();
		scripts.call("beatHit", [curBeat]);

		if (SONG.notes[Math.floor(curStep / 16)] != null)
		{
			if (SONG.notes[Math.floor(curStep / 16)].changeBPM)
			{
				Conductor.changeBPM(SONG.notes[Math.floor(curStep / 16)].bpm);
				FlxG.log.add('CHANGED BPM!');
			}
		}
		
		// HARDCODING FOR MILF ZOOMS!
		// if (curSong.toLowerCase() == 'milf' && curBeat >= 168 && curBeat < 200 && camZooming && FlxG.camera.zoom < 1.35)
		// {
		// 	FlxG.camera.zoom += 0.015;
		// 	camHUD.zoom += 0.03;
		// }

		if (camZoomingInterval < 1) camZoomingInterval = 1;
		if (camZooming && FlxG.camera.zoom < 1.35 && curBeat % camZoomingInterval == 0)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;
		}

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		// if (curBeat % gfSpeed == 0)
		// {
		// 	gf.dance();
		// }
	}

	public var curLight:Int = 0;
}