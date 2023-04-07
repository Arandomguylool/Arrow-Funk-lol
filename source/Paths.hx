package;

import flixel.FlxG;
import openfl.system.System;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.display3D.textures.Texture;
import lime.utils.Assets;
import flixel.FlxSprite;
#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
import openfl.display.BitmapData;
#end
import flash.media.Sound;

#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif java
import java.vm.Gc;
#elseif neko
import neko.vm.Gc;
#end

using StringTools;

class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;

	#if MODS_ALLOWED
	#if (haxe >= "4.0.0")
	public static var customImagesLoaded:Map<String, Bool> = new Map();
	public static var customSoundsLoaded:Map<String, Sound> = new Map();
	#else
	public static var customImagesLoaded:Map<String, Bool> = new Map<String, Bool>();
	public static var customSoundsLoaded:Map<String, Sound> = new Map<String, Sound>();
	#end
	
	public static var ignoreModFolders:Array<String> = [
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'images',
		'stages',
		'weeks'
	];
	#end

	private static var currentTrackedAssets:Map<String, Map<String, Dynamic>> = ["textures" => [], "graphics" => [], "sounds" => []];
	private static var localTrackedAssets:Map<String, Array<String>> = ["graphics" => [], "sounds" => []];

	public static final extensions:Map<String, String> = ["image" => "png", "audio" => "ogg", "video" => "mp4"];

	public static var dumpExclusions:Array<String> = [];

	public static function excludeAsset(key:String):Void {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static function clearUnusedMemory():Void {
		for (key in currentTrackedAssets["graphics"].keys()) {
			@:privateAccess
			if (!localTrackedAssets["graphics"].contains(key)) {
				if (currentTrackedAssets["textures"].exists(key)) {
					var texture:Null<Texture> = currentTrackedAssets["textures"].get(key);
					texture.dispose();
					texture = null;
					currentTrackedAssets["textures"].remove(key);
				}

				var graphic:Null<FlxGraphic> = currentTrackedAssets["graphics"].get(key);
				OpenFlAssets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				graphic.destroy();
				currentTrackedAssets["graphics"].remove(key);
			}
		}

		for (key in currentTrackedAssets["sounds"].keys()) {
			if (!localTrackedAssets["sounds"].contains(key)) {
				OpenFlAssets.cache.removeSound(key);
				currentTrackedAssets["sounds"].remove(key);
			}
		}

		// run the garbage collector for good measure lmfao
		#if (cpp || neko || java || hl)
		Gc.run(true);
		Gc.compact();
		#end
	}

	public static function clearStoredMemory():Void {
		FlxG.bitmap.dumpCache();

		@:privateAccess
		for (key in FlxG.bitmap._cache.keys()) {
			if (!currentTrackedAssets["graphics"].exists(key)) {
				var graphic:Null<FlxGraphic> = FlxG.bitmap._cache.get(key);
				OpenFlAssets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				graphic.destroy();
			}
		}

		for (key in OpenFlAssets.cache.getSoundKeys()) {
			if (!currentTrackedAssets["sounds"].exists(key))
				OpenFlAssets.cache.removeSound(key);
		}

		for (key in OpenFlAssets.cache.getFontKeys())
			OpenFlAssets.cache.removeFont(key);

		localTrackedAssets["sounds"] = localTrackedAssets["graphics"] = [];
	}
	
	static public var currentModDirectory:String = '';
	static var currentLevel:String;
	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, type:AssetType, ?library:Null<String> = null)
	{
		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(file, currentLevel);
				if (OpenFlAssets.exists(levelPath, type))
					return levelPath;
			}

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		return '$library:assets/$library/$file';
	}

	inline public static function getPreloadPath(file:String = '')
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline static public function lua(key:String, ?library:String)
	{
		return getPath('$key.lua', TEXT, library);
	}

	static public function sound(key:String, ?library:String):Dynamic
	{
		#if MODS_ALLOWED
		var file:String = modsSounds(key);
		if(FileSystem.exists(file)) {
			if(!customSoundsLoaded.exists(file)) {
				customSoundsLoaded.set(file, Sound.fromFile(file));
			}
			return customSoundsLoaded.get(file);
		}
		#end
		return getPath('sounds/$key.$SOUND_EXT', SOUND, library);
	}
	
	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function music(key:String, ?library:String):Dynamic
	{
		#if MODS_ALLOWED
		var file:String = modsMusic(key);
		if(FileSystem.exists(file)) {
			if(!customSoundsLoaded.exists(file)) {
				customSoundsLoaded.set(file, Sound.fromFile(file));
			}
			return customSoundsLoaded.get(file);
		}
		#end
		return getPath('music/$key.$SOUND_EXT', MUSIC, library);
	}

	inline static public function voices(song:String):Any
	{
		#if MODS_ALLOWED
		var file:Sound = returnSongFile(modsSongs(song.toLowerCase().replace(' ', '-') + '/Voices'));
		if(file != null) {
			return file;
		}
		#end
		return 'songs:assets/songs/${song.toLowerCase().replace(' ', '-')}/Voices.$SOUND_EXT';
	}

	inline static public function inst(song:String):Any
	{
		#if MODS_ALLOWED
		var file:Sound = returnSongFile(modsSongs(song.toLowerCase().replace(' ', '-') + '/Inst'));
		if(file != null) {
			return file;
		}
		#end
		return 'songs:assets/songs/${song.toLowerCase().replace(' ', '-')}/Inst.$SOUND_EXT';
	}

	#if MODS_ALLOWED
	inline static private function returnSongFile(file:String):Sound
	{
		if(Util.exists(file)) {
			if(!customSoundsLoaded.exists(file)) {
				customSoundsLoaded.set(file, Sound.fromFile(file));
			}
			return customSoundsLoaded.get(file);
		}
		return null;
	}
	#end

	public static function image(key:String, ?library:String):FlxGraphic {
		var returnAsset:FlxGraphic = returnGraphic(key, library);
		return returnAsset;
	}


	public static function returnGraphic(key:String, ?library:String) {
		var path:String = getPath('images/$key.png', IMAGE, library);
		if (OpenFlAssets.exists(path)) {
			if (!currentTrackedAssets["graphics"].exists(path)) {
				var graphic:FlxGraphic;
				var bitmapData:BitmapData = OpenFlAssets.getBitmapData(path);

				if (ClientPrefs.permitirgpu) {
					#if (debug && !mobile)
					trace('carregando $path por GPU'); //Apenas para trackear se tem alguma coisa ocupando memória onde não deveria.
					//Isso faz o jogo lagar um pouquinho, mas é só no debug mesmo pra saber se não tem nada absurdo sendo carregado.
					#end
					var texture:Texture = FlxG.stage.context3D.createTexture(bitmapData.width, bitmapData.height, BGRA, true);
					texture.uploadFromBitmapData(bitmapData);
					currentTrackedAssets["textures"].set(path, texture);

					bitmapData.disposeImage();
					bitmapData.dispose();
					bitmapData = null;

					graphic = FlxGraphic.fromBitmapData(openfl.display.BitmapData.fromTexture(texture), false, path);
				} else{
					#if (debug && !mobile)
					trace('carregando $path por CPU');
					#end
					graphic = FlxGraphic.fromBitmapData(bitmapData, false, path);
				}

				graphic.persist = true;
				currentTrackedAssets["graphics"].set(path, graphic);
			}

			localTrackedAssets["graphics"].push(path);
			return currentTrackedAssets["graphics"].get(path);
		}
		FlxG.log.error('oh no $path is returning null NOOOO');
		return null; //Apenas para garantir que o jooj tentará carregar do jeito normal primeiro (ou então ajuidar a descobrir qual o pilantra.)
	}


	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(mods(key)))
			return File.getContent(mods(key));
		#end

		if (Util.exists(getPreloadPath(key)))
			return Util.getContent(getPreloadPath(key));

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(key, currentLevel);
				if (Util.exists(levelPath))
					return Util.getContent(levelPath);
			}

			levelPath = getLibraryPathForce(key, 'shared');
			if (Util.exists(levelPath))
				return File.getContent(levelPath);
		}
		#end
		return Assets.getText(getPath(key, TEXT));
	}

	inline static public function font(key:String)
	{
		return 'assets/fonts/$key';
	}

	inline static public function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String)
	{
		#if MODS_ALLOWED
		if(FileSystem.exists(mods(currentModDirectory + '/' + key)) || FileSystem.exists(mods(key))) {
			return true;
		}
		#end
		
		if(OpenFlAssets.exists(Paths.getPath(key, type))) {
			return true;
		}
		return false;
	}

inline static public function getSparrowAtlas(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
	}

	inline static public function getPackerAtlas(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
	}


	inline static public function formatToSongPath(path:String) {
		return path.toLowerCase().replace(' ', '-');
	}
	
	#if MODS_ALLOWED
	static public function addCustomGraphic(key:String):FlxGraphic {
		if(FileSystem.exists(modsImages(key))) {
			if(!customImagesLoaded.exists(key)) {
				var newBitmap:BitmapData = BitmapData.fromFile(modsImages(key));
				var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(newBitmap, false, key);
				newGraphic.persist = true;
				FlxG.bitmap.addGraphic(newGraphic);
				customImagesLoaded.set(key, true);
			}
			return FlxG.bitmap.get(key);
		}
		return null;
	}

	inline static public function mods(key:String = '') {
		return 'mods/' + key;
	}

	inline static public function modsJson(key:String) {
		return modFolders('data/' + key + '.json');
	}

	inline static public function modsMusic(key:String) {
		return modFolders('music/' + key + '.' + SOUND_EXT);
	}

	inline static public function modsSounds(key:String) {
		return modFolders('sounds/' + key + '.' + SOUND_EXT);
	}

	inline static public function modsSongs(key:String) {
		return modFolders('songs/' + key + '.' + SOUND_EXT);
	}

	inline static public function modsImages(key:String) {
		return modFolders('images/' + key + '.png');
	}

	inline static public function modsXml(key:String) {
		return modFolders('images/' + key + '.xml');
	}

	inline static public function modsTxt(key:String) {
		return modFolders('images/' + key + '.txt');
	}

	static public function modFolders(key:String) {
		if(currentModDirectory != null && currentModDirectory.length > 0) {
			var fileToCheck:String = mods(currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck)) {
				return fileToCheck;
			}
		}
		return 'mods/' + key;
	}

	static public function getModDirectories():Array<String> {
		var list:Array<String> = [];
		var modsFolder:String = Paths.mods();
		if(FileSystem.exists(modsFolder)) {
			for (folder in FileSystem.readDirectory(modsFolder)) {
				var path = haxe.io.Path.join([modsFolder, folder]);
				if (sys.FileSystem.isDirectory(path) && !Paths.ignoreModFolders.contains(folder) && !list.contains(folder)) {
					list.push(folder);
				}
			}
		}
		return list;
	}
	#end
}
