/*
* min examples on [http://en.wikipedia.org/wiki/ActionScript ActionScript - Wikipedia, the free encyclopedia] 
* but this is the basic one here: [http://www.williambrownstreet.net/wordpress/?p=78 Flash/ActionScript3 “Programming” under Ubuntu at William Brown Street]

see also (for setup of Adobe's flex_sdk[_3.5..])
* [http://www.dotkam.com/2009/03/29/adobe-flex-in-ubuntu-develop-compile-and-run/ Adobe Flex in Ubuntu: Develop, Compile and Run]
* [http://osflash.org/linux Developing for the Flash Platform using Linux Open Source Flash]

... then build with: 
mxmlc HelloWorld_flex.as
# generates HelloWorld_flex.swf

Note first: 
HelloWorld_flex.as: Error: A file found in a source-path 'HelloWorld_flex' must have the same name as the class definition inside the file 'HelloWorld'.

AS2: http://www.actionscript.org/resources/articles/751/2/Flex-and-MVC---Part-I/Page2.html

* "http://aralbalkan.com/640" t="Aral Balkan · Some notes on migrating applications from Flex 1.5 (AS2) to Flex 2 (AS3)"
* http://interactivemultimedia.wordpress.com/2008/01/30/going-from-flash-actionscript-3-to-actionscript-2/ 

See also: 
http://stackoverflow.com/questions/4528144/can-an-actionscript-2-0-single-file-be-compiled-with-flex-3-x-mxmlc
"No, no and no" - so AS2 syntax has to be mtasc... (in apt-get)
	mtasc compile line is: 
mtasc -v -swf HelloWorld_flex.swf -main -header 800:600:20 HelloWorld_flex.as

*/

// AS2 syntax - mtasc.. 
// class doesn't have to have the same name as file.. 
class Tuto {

	static var app : Tuto;

	function Tuto() {
		// creates a 'tf' TextField size 800x600 at pos 0,0
		_root.createTextField("tf",0,0,0,800,600);
		// write some text into it
		_root.tf.text = "Hello world !";
	}

	// entry point
	static function main(mc) {
		app = new Tuto();
	}
}


/*
// AS3 syntax - cannot open in Gnash (tf not rendered) 
package {
    import flash.display.Sprite;
    import flash.text.TextField;
   
    public class HelloWorld_flex extends Sprite {
       
        public function HelloWorld_flex() {
            var display_txt:TextField = new TextField();
            display_txt.text = "Hello World!";
            addChild(display_txt);
        }
    }
}
*/

/*
// AS2 syntax? flex 3.5 mxmlc chokes on this.. 
<?xml version="1.0" encoding="utf-8"?>
<mx:Application xmlns:mx="http://www.adobe.com/2006/mxml">

<mx:Script>
<![CDATA[
import mx.controls.Alert;

// Business Logic
private function clickHandler():void
{
// Model
result.text += personName.text;
}
]]>
</mx:Script>

// View
<mx:TextInput id="personName" />

<mx:Text id="result" text="" />

<mx:Button id="showHello" label="Say Hello" click="clickHandler();"/>
</mx:Application>
*/

