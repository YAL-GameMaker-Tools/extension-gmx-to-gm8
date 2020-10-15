package;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

/**
 * ...
 * @author YellowAfterlife
 */
class ExtGmxToGml8 {
	
	static function error(s:String) {
		Sys.println(s);
		Sys.exit(0);
	}
	
	/** <par><node x></par>, "node" -> <node x> */
	static function xmlFind(xml:Xml, name:String):Xml {
		var iter = xml.elementsNamed(name);
		if (iter.hasNext()) {
			return iter.next();
		} else {
			error('Could not find <$name> in the GMX.');
			return null;
		}
	}
	
	/** <node>text</node> -> "text" */
	static function xmlRead(xml:Xml):String {
		return xml.firstChild().toString();
	}
	
	static function main() {
		var args = Sys.args();
		if (args.length < 1) {
			Sys.println("Usage: .../some.extension.gmx [.../out.gml] [scr_entrypoint]");
			Sys.println("1: [required] Path to an .extension.gmx in a project directory.");
			Sys.println("2: [optional] Path to the resulting .gml file.");
			Sys.println("3: [optional] Name of the entrypoint/init script in the resulting file.");
			return;
		}
		var xmlPath = args[0], outPath, outName;
		if (args.length < 2) {
			outPath = Path.withoutExtension(xmlPath);
			if (Path.extension(outPath).toLowerCase() == "extension") {
				outPath = Path.withoutExtension(outPath);
			}
			outPath += ".gml";
		} else outPath = args[1];
		if (args.length < 3) {
			outName = Path.withoutExtension(Path.withoutDirectory(outPath));
		} else outName = args[2];
		//
		var text:String = File.getContent(xmlPath);
		var xmlRoot:Xml = haxe.xml.Parser.parse(text);
		var extNode:Xml = xmlFind(xmlRoot, "extension");
		var extName:String = xmlRead(xmlFind(extNode, "name"));
		var extFiles:Xml = xmlFind(extNode, "files");
		var extDir:String = Path.directory(xmlPath) + "/" + extName;
		var init:StringBuf = new StringBuf();
		var out:StringBuf = new StringBuf();
		var buf:StringBuf;
		init.add('#define ${outName}\n');
		for (fileNode in extFiles.elementsNamed("file")) {
			var fileName = xmlRead(xmlFind(fileNode, "filename"));
			switch (Path.extension(fileName).toLowerCase()) {
				case "gml": {
					out.add(File.getContent('$extDir/$fileName'));
				};
				case "dll": {
					buf = new StringBuf();
					for (funcNode in xmlFind(fileNode, "functions").elementsNamed("function")) {
						var funcName = xmlRead(xmlFind(funcNode, "name"));
						var funcXName = xmlRead(xmlFind(funcNode, "externalName"));
						var funcKind = Std.parseInt(xmlRead(xmlFind(funcNode, "kind")));
						var funcKindGml = funcKind == 11 ? "dll_stdcall" : "dll_cdecl";
						var funcRt = Std.parseInt(xmlRead(xmlFind(funcNode, "returnType")));
						var funcRtGml = funcRt == 1 ? "ty_string" : "ty_real";
						var funcArgs = Std.parseInt(xmlRead(xmlFind(funcNode, "argCount")));
						var funcHelp = xmlRead(xmlFind(funcNode, "help"));
						//
						buf.add('global.f_$funcName = external_define(_path, ');
						buf.add('"$funcXName", $funcKindGml, $funcRtGml, $funcArgs');
						for (argNode in xmlFind(funcNode, "args").elementsNamed("arg")) {
							buf.add(", " + (xmlRead(argNode) == "1" ? "ty_string" : "ty_real"));
						}
						buf.add(");\n");
						//
						out.add('\n#define $funcName\n');
						if (funcHelp != "") out.add('/// $funcHelp\n');
						out.add('return external_call(global.f_$funcName');
						for (i in 0 ... funcArgs) out.add(', argument$i');
						out.add(');\n');
					}
					var fileInit = xmlRead(xmlFind(fileNode, "init"));
					if (fileInit != "") buf.add('$fileInit();\n');
					if (buf.length > 0) {
						init.add('// $fileName:\r\n');
						init.add('var _path = "$fileName";\r\n');
						init.add(buf.toString());
					}
				};
			}
		} // for (fileNode)
		if (out.length > 0) init.add(out.toString());
		File.saveContent(outPath, init.toString());
	}
	
}
