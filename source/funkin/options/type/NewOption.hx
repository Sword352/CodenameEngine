package funkin.options.type;

import flixel.util.FlxColor;
import funkin.game.HealthIcon;

class NewOption extends TextOption {
	public var iconSpr:FlxSprite;

	public function new(name:String, desc:String, callback:Void->Void) {
		super(name, desc, callback);

		__text.color = FlxColor.LIME;

		iconSpr = new FlxSprite().loadGraphic(Paths.image("editors/new"));
		iconSpr.setPosition(90 - iconSpr.width, (__text.height - iconSpr.height) / 2);
		add(iconSpr);
	}
}