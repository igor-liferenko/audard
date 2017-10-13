-- ONLY EDIT THIS HERE, IF PREVIOUS TAB PWD WAS IN /~ !!!
-- AND DO TYPE PWD TO MAKE SCITE AWARE!!
-- easypaste: PERL_LWP_SSL_VERIFY_HOSTNAME=0 mvs li
print(package.path)
-- ld is the directory scite is started from
-- also remove last \n using substring (is 1-based)
local ld = string.sub(io.popen("pwd"):read("*a"), 1, -2) -- read output of command;
print(ld) -- print ld (current) directory
-- script path seems correct here (the home dir /~ resolved)
function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*/)")
end
--~ print(script_path())
-- append script_path to package.path
--~ table.insert(package.loaders, script_path) -- nowork
package.path = package.path .. ";" .. script_path() .. "?.lua"
print(package.path) -- now have no errors if I start scite from the command line (with SciTEHexEdit.lua etc..)


------------------------------------------------------------------------
-- based on:
-- "Dir (objects introspection like Python's dir) - Lua"
-- http://lua-users.org/wiki/IntrospectionFunctionsLua
------------------------------------------------------------------------
function dir(obj,level)
  local s,t = '', type(obj)

  level = level or ' '

  if (t=='nil') or (t=='boolean') or (t=='number') or (t=='string') then
    s = tostring(obj)
    if t=='string' then
      s = '"' .. s .. '"'
    end
  elseif t=='function' then s='function'
  elseif t=='userdata' then
    s='userdata'
    for n,v in pairs(getmetatable(obj)) do  s = s .. " (" .. n .. "," .. dir(v) .. ")" end
  elseif t=='thread' then s='thread'
  elseif t=='table' then
    s = '{'
    for k,v in pairs(obj) do
      local k_str = tostring(k)
      if type(k)=='string' then
        k_str = '["' .. k_str .. '"]'
      end
      s = s .. k_str .. ' = ' .. dir(v,level .. level) .. ', '
    end
    s = string.sub(s, 1, -3)
    s = s .. '}'
  end
  return s
end



-- note: "SciTEHexEdit.lua" raises an error! can do both ("SciTEHexEdit") and "SciTEHexEdit"
require("SciTEHexEdit")
require("SciTELineBreak")
require("SciTE-aspell")



function PrintProps()
  print(editor)
  print(props)
  print(tostring(editor))
  print(tostring(props))
  print(getmetatable(editor))
  print(getmetatable(props))

  -- iterate over array:

  -- bad argument #1 to 'pairs' (table expected, got userdata):
  --~ for i,v in pairs(editor) do print(i,v) end
  --~ for i,v in pairs(props) do print(i,v) end

  -- ipairs don't work below?
  print("---1---")
  for i,v in pairs(getmetatable(editor)) do print(i,v) end
  print("---2---")
  for i,v in pairs(getmetatable(props)) do print(i,v) end

  prtab = getmetatable(props)
  local function __index (tab,key)
    -- print(key)
    return key
  end
  setmetatable(prtab,{__index = __index})

  print(toazt)
end

function CopyPath()
  -- editor:CopyText(props.FilePath, string.len(props.FilePath)) -- commented
  editor:CopyText(props.FilePath)
end

function SelAppendEOF()
  local sel = editor:GetSelText()
  editor:AppendText(sel .. "\n")
end

function InsertCodeTag()
  editor:InsertText(editor.CurrentPos,"<code></code>")
  -- editor.CurrentPos = editor.CurrentPos + 6 -- this selects!
  editor:GotoPos(editor.CurrentPos + 6)
end

function InsertQpTag()
  local sel = editor:GetSelText()
  if string.len(sel) ~= 0 then
    editor:ReplaceSel("<qp>" .. sel .. "</qp>")
  else
    editor:InsertText(editor.CurrentPos,"<qp></qp>")
    -- position cursor in between the tags
    -- editor.CurrentPos = editor.CurrentPos + 4 -- this selects!
    editor:GotoPos(editor.CurrentPos + 4)
  end
end

function InsertDate()
  local f = io.popen("date") -- runs command
  local l = f:read("*a") -- read output of command
  editor:InsertText(editor.CurrentPos,l)
end

function PasteJoinSave()
  -- does NOT work with intern Scite copy;
  -- but works with extern copy...
--~   local cmd = "echo \"$(timeout -9 1 xclip -l 0 -selection clipboard -o)\"" -- older timeout
  local cmd = "echo \"$(timeout -k 1 1 xclip -l 0 -selection clipboard -o)\"" -- newer timeout
  print(cmd)
  local f = io.popen(cmd) -- runs command
  local clip = f:read("*all") -- read output of command

  -- note - unicode may arrive well here; but if File/Encoding is not set to UTF-8, then garbage may appear- fix in User.properties!! (LC_CTYPE=en_US.UTF-8 etc..)

--~   print(clip)
  local clipline = string.gsub(clip, "[\r\n]", " ")
--~   print(clipline)
  -- inset at current caret position
  editor:InsertText(editor.CurrentPos,clipline)
  -- move caret to end of line (else it stays where it is)
  editor:LineEnd()
  -- get current position of caret
  --local curpos_ = editor:GetCurrentPos()
   -- [http://sourceforge.net/tracker/?func=detail&aid=1785570&group_id=2439&atid=102439 SourceForge.net: Scintilla: Detail: 1785570 - LUA output:GetCurrentPos not functioning normally]
  local curpos_ = editor.CurrentPos
  -- add a final LF at that position - instead of via insert text
  editor:InsertText(editor.CurrentPos,"\n\n")
  -- that still don't move the caret - so set the caret current position
  editor:GotoPos(curpos_+2)
  -- no lua command to save - use saveafter:yes in User.properties? there is no saveafter - only savebefore;
  -- http://little-ide.googlecode.com/svn-history/r48/trunk/littleide/src/scite-debug/scite_lua/prompt.lua
  -- http://scite-interest.googlegroups.com/web/SciTELua.api -- DEAD
  -- http://groups.google.com/group/scite-interest/browse_thread/thread/03767b2b2853d189 [SciTELua.api]
  -- http://scite-ru.googlecode.com/svn/trunk/pack/api/SciTELua.api -- ok, but ru?
  -- http://scintilla.hg.sourceforge.net/hgweb/scintilla/scintilla/file/b610e856664d/include/Scintilla.iface -- C??
  -- http://little-ide.googlecode.com/svn-history/r48/trunk/littleide/src/scite-debug/scite_lua/prompt.lua
  -- http://www.scintilla.org/CommandValues.html
  -- works OK:
  scite.MenuCommand(IDM_SAVE)
  -- now, bind to F9 ("But you can use any number less than 50 in these definitions, as long as you give an explicit shortcut key" - http://lua-users.org/wiki/UsingLuaWithScite) - for use with onboard keyboard..
end


function SelAppendClipboard()
  --print(editor)
  local selorig = editor:GetSelText()
  -- escape bloody quotes
--~   local sel = string.gsub(selorig, '"', '\\"')


  local tezt = editor:GetClipboard()
  print(tezt .. "/////")
  local tezt2 = tezt .. selorig
  editor:SetClipboard(tezt2)
  print(tezt2)
  print("--")

  --local f = io.popen("echo $(xclip -out -selection clipboard)") -- runs command
  -- os.execute("echo $(xclip -l 1 -o)") -- runs command
  -- os.execute("bash -c 'xclip -o'") -- runs command
  -- local cmd = '"echo \\"' .. sel .. '\\" \\| xsel --clipboard -a"'
  -- local cmd = 'echo "' .. sel .. '" | xsel --clipboard -a'
  -- local cmd = 'bash -c "appendclipboard \\"' .. sel2 .. '\\""'

--~   local cmd = 'bash -c \'appendclipboard "' .. sel .. '"\''
--~   print(cmd)

--~   local ret = os.execute(cmd)
--~   print(ret)

--~   f = io.popen(cmd) -- runs command
--~   l = f:read("*a") -- read output of command
--~   print(l)

  --local clipboardcontent = f:read("*a") -- read output of command
  -- local newclip = clipboardcontent .. "\n" .. sel
  --print(clipboardcontent)
  -- editor:CopyText(newclip)
end

-- via http://untidy.net/blog/2008/06/03/line-movement-commands-with-pypn/
function MoveLineUp()
  local l = editor:LineFromPosition(editor.CurrentPos)
  if (l == 0) then return end

  editor:BeginUndoAction()
  editor:LineTranspose()
  editor:LineUp()
  editor:EndUndoAction()
end

function MoveLineDown()
  local l = editor:LineFromPosition(editor.CurrentPos)
  if (l == editor.LineCount) then return end

  editor:BeginUndoAction()
  editor:LineDown()
  editor:LineTranspose()
  editor:EndUndoAction()
end


-- complex problem to clean split tags in lines
    -- http://stackoverflow.com/a/1365021/277826 /<.*?>/
    -- local clnd = string.gsub(clnd, "<.*>", "")
-- so have to do a char by char filter
-- see http://stackoverflow.com/questions/829063/how-to-iterate-individual-characters-in-lua-string
-- http://stackoverflow.com/questions/1405583/concatenation-of-strings-in-lua
function CleanTags()
  editor:BeginUndoAction()
    local sel = editor:GetSelText()
    local clnd = ""
    local icnt = 0
    local tarr = { }
    local darr = { } -- dumped chars

    -- assume NOT starting at tag
    local intag = false
    -- to handle deletion of closing `>` of a tag
    local closetag = false
    --
    local aftertagopen = false
    local istagopen = false -- assume </ - closing tag at first
    local intagname = -1 -- are we reading the tag name
    local readtagname = false -- are we reading the tag name
    local tagnamearr = { }

    for c in sel:gmatch"." do -- note; a regex match!
      -- do something with c
      -- print(c)
      local shouldPass = true
      closetag = false -- must reset each time
      -- this one before the main run:
      if aftertagopen then
        -- at second letter, after `<`
        -- is it opening or closing tag?
        if c == "/" then
          istagopen = false
          --intagname = 1
        else
          istagopen = true
          --intagname = 0
        end
        aftertagopen = false
        readtagname = true --
        tagnamearr = { } --
      end
      -- don't bother with this, capture name tags with /
--~       if intagname == 0 then
--~         readtagname = true
--~         tagnamearr = { }
--~         intagname = -1 -- started reading, conclude
--~       elseif intagname > 0 then
--~         intagname = intagname - 1 --delay once if in closing tag
--~       end

      if readtagname then
        -- on match whitespace, break
        -- lua-specific whitespace regex ("pattern") %s, not \s
        -- if match is not nil:
        if c:match("[%s>]") ~= nil then
          readtagname = false
          -- dump read tagname
          print(table.concat(tagnamearr,""))
        else
          tagnamearr[#tagnamearr+1] = c
        end
      end

      if c == "<" then
        if not(intag) then
          intag = true
          aftertagopen = true
        end
      elseif c == ">" then
        if intag then
          intag = false
          closetag = true
        end
      end

      if intag then shouldPass = false end
      if closetag then shouldPass = false end
      -- if c == "\n" then shouldPass = true end -- no need; delete \n if it breaks within a tag
      if shouldPass then
        tarr[#tarr+1] = c
      else
        darr[#darr+1] = c
      end

    end -- end for

    clnd = table.concat(tarr,"")
    editor:ReplaceSel(clnd)
    print(table.concat(darr,""))
    print()
  editor:EndUndoAction()
end


function CleanTexEquations()
  editor:BeginUndoAction()
    local sel = editor:GetSelText()
    local clnd = sel

    local clnd = string.gsub(clnd, "\\normalsubformula", "")
    local clnd = string.gsub(clnd, "\\text", "")
    local clnd = string.gsub(clnd, "\\mathit", "")
    local clnd = string.gsub(clnd, "{%.}", ".")
    local clnd = string.gsub(clnd, "{{", "{")
    local clnd = string.gsub(clnd, "}}", "}")

    editor:ReplaceSel(clnd)
  editor:EndUndoAction()
end

function SpaceTexEquations()
  editor:BeginUndoAction()
    local sel = editor:GetSelText()
    local clnd = sel
    clnd = string.gsub(clnd, "-", " - ")
    clnd = string.gsub(clnd, "+", " + ")
    clnd = string.gsub(clnd, "=", " = ")
    clnd = string.gsub(clnd, "\\approx", " \\approx ")
    clnd = string.gsub(clnd, "\\left%(", " \\left( ")
    -- must escape here with % as ) is magic char.. but \ works for escaping \ ?
    clnd = string.gsub(clnd, "\\right%)", " \\right) ")

    editor:ReplaceSel(clnd)
  editor:EndUndoAction()
end

-- SEE [http://www.mail-archive.com/scite-interest@lyra.org/msg03520.html [scite] Re: save after] !!!
function MvsCnr()
 -- print(os.execute("pwd")) -- just writes 0
 -- http://lua-users.org/lists/lua-l/2007-04/msg00085.html
 -- io.write(os.execute("pwd"))  -- should write both out and 0, but does nothing
 local f = io.popen("pwd") -- runs command
 local l = f:read("*a") -- read output of command
 print(l) -- print current directory

 local cfn = props['FileName'] -- current file name, hopefully '*.wiki'
 local cfe = props['FileExt'] -- current file ext, hopefully 'wiki'
 local cmd = "PERL_LWP_SSL_VERIFY_HOSTNAME=0 mvs cnr " .. cfn .. "." .. cfe
 print(cmd)
 f = io.popen(cmd) -- runs command
 l = f:read("*a") -- read output of command
 print(l) -- print output
 local cmd = "PERL_LWP_SSL_VERIFY_HOSTNAME=0 mvs up " .. cfn .. "." .. cfe
 print(cmd)
 f = io.popen(cmd) -- runs command
 l = f:read("*a") -- read output of command
 print(l) -- print output
end

function PdfLatex()
 -- print(os.execute("pwd")) -- just writes 0
 -- http://lua-users.org/lists/lua-l/2007-04/msg00085.html
 -- io.write(os.execute("pwd"))  -- should write both out and 0, but does nothing
 local f = io.popen("pwd") -- runs command
 -- also remove last \n using substring (is 1-based)
 local l = string.sub(f:read("*a"),1,-2) -- read output of command
--~  print(l) -- print current directory

 local cfn = props['FileName'] -- current file name, hopefully '*.tex'
 local cfe = props['FileExt'] -- current file ext, hopefully 'tex'
 -- use ; instead of && - sometimes pdflatex may complete while exiting w/ fail!
 -- -interaction=scrollmode to suppress some errors; -shell-escape to enable write18
 -- NOTE: TEXINPUTS=.//:$TEXINPUTS may cause "Permission denied",
 -- if we're running this on a file in /tmp (bash -c is not needed)!
 -- so change the cmd as necessarry....
--~  local cmd = "TEXINPUTS=.//:$TEXINPUTS pdflatex " .. cfn .. "." .. cfe
 local cmd = "pdflatex " .. cfn .. "." .. cfe
--~  local cmd = "lualatex " .. cfn .. "." .. cfe
--~  cmd = cmd .. " && bibtex " .. cfn
--~  local cmd = "TEXINPUTS=.//:$TEXINPUTS pdflatex " .. cfn .. "." .. cfe .. " && biber " .. cfn
--~  cmd = cmd .. " && bibtex " .. cfn .. " && pdflatex " .. cfn .. "." .. cfe .. " && pdflatex " .. cfn .. "." .. cfe
 print(cmd)
 -- io.popen could fail with pdflatex when it waits from stdin
--~  f = io.popen(cmd) -- runs command
--~  l = f:read("*a") -- read output of command
--~  print(l) -- print output
 -- if scite is RAN FROM COMMAND LINE !!!!! ,
 -- os.execute will allow interaction in cmd window!
--~  io.write(os.execute(cmd)) -- io.write not even needed then!
 os.execute(cmd)
end

function EQuotePlusOne()
 -- table: http://lua-users.org/lists/lua-l/2006-09/msg00388.html
 -- http://lua-users.org/wiki/SciteCommentBox
 -- make sure you select entire line(s) (for now)

  -- quote character - '>'
  qch=">"

  --~ 	retrieve selected region...
  oldss=editor.SelectionStart
  oldse=editor.SelectionEnd
  p1=editor:LineFromPosition(oldss);
  p2=editor:LineFromPosition(oldse);

  --~ 	if nothing selected, then take the line we are working on
  if p1==p2 then
    p2=p1+1
  end

  --~ 	read the lines in the selection to an array
  --~ 	 + add some new text to start and end (view config up here)
  -- lines = read_lines(p1,p2)
  local sellines = {}
  --~ 	add the text
  for i=p1,p2-1 do -- was: start_line,end_line-1
    line=editor:GetLine(i)

    --~ 		remove returns, -- and replace tabs by the userdefined nr of spaces
    line=string.gsub(line, "\n", "")
    line=string.gsub(line, "\r", "")
    -- line=string.gsub(line, "\t", string.rep(" ", props['tabsize']))

    -- get first two characters of line - substring
    -- from character 1 until and including 2
    fchars = string.sub(line, 1, 2)

    -- if already quoted, just add additional quotechar
    if fchars == qch.." " or fchars == qch..qch then
      line = qch .. line
    else -- add quotechar + space as first
      line = qch .. " " .. line
    end

    table.insert(sellines,table.getn(sellines)+1,line)
  end

  --~ 	format the text...  --text = format_text(lines, max_str_len)
  orets = ""

  for i=1,table.getn(sellines) do
    orets=orets..sellines[i]
                    .."\n"
  end

  --~ 	and replace!
  editor:ReplaceSel(orets)
  --~ 	print(orets)

  -- since the above kills selection, restore
  -- however, due to added chars, old selection is changes
  -- so recalc new selection points based on line start
  newss = editor:PositionFromLine(p1)
  newse = editor:PositionFromLine(p2)
  editor:SetSel(newss, newse)
end

function EQuoteMinusOne()
 -- table: http://lua-users.org/lists/lua-l/2006-09/msg00388.html
 -- http://lua-users.org/wiki/SciteCommentBox
 -- make sure you select entire line(s) (for now)

  -- quote character - '>'
  qch=">"

  --~ 	retrieve selected region...
  oldss=editor.SelectionStart
  oldse=editor.SelectionEnd
  p1=editor:LineFromPosition(oldss);
  p2=editor:LineFromPosition(oldse);

  --~ 	if nothing selected, then take the line we are working on
  if p1==p2 then
    p2=p1+1
  end

  --~ 	read the lines in the selection to an array
  --~ 	 + add some new text to start and end (view config up here)
  -- lines = read_lines(p1,p2)
  local sellines = {}
  --~ 	add the text
  for i=p1,p2-1 do -- was: start_line,end_line-1
    line=editor:GetLine(i)

    --~ 		remove returns, -- and replace tabs by the userdefined nr of spaces
    line=string.gsub(line, "\n", "")
    line=string.gsub(line, "\r", "")
    -- line=string.gsub(line, "\t", string.rep(" ", props['tabsize']))

    -- get first two characters of line - substring
    -- from character 1 until and including 2
    fchars = string.sub(line, 1, 2)

    -- for double quotes, simply remove one
    if fchars == qch..qch then
      line = string.sub(line, 2, -1) -- from 2nd char to end
    -- for quote and space, remove both
    elseif fchars == qch.." " then
      line = string.sub(line, 3, -1) -- from 3rd char to end
    -- just one on empty line - remove it
    elseif fchars == qch then
      line = string.sub(line, 2, -1)
    end

    table.insert(sellines,table.getn(sellines)+1,line)
  end

  --~ 	format the text...  --text = format_text(lines, max_str_len)
  orets = ""

  for i=1,table.getn(sellines) do
    orets=orets..sellines[i]
                    .."\n"
  end

  --~ 	and replace!
  editor:ReplaceSel(orets)
  --~ 	print(orets)

  -- since the above kills selection, restore
  -- however, due to added chars, old selection is changes
  -- so recalc new selection points based on line start
  newss = editor:PositionFromLine(p1)
  newse = editor:PositionFromLine(p2)
  editor:SetSel(newss, newse)
end

function WcalcSel()
--~   -- retrieve selected region...
  oldss=editor.SelectionStart
  oldse=editor.SelectionEnd
--~   p1=editor:LineFromPosition(oldss);
--~   p2=editor:LineFromPosition(oldse);
--~   -- if nothing selected, then take the line we are working on
--~   if p1==p2 then
--~     p2=p1+1
--~   end

  local sel = editor:GetSelText()

  -- not equal is '~=', not '!=' or '<>'
  if sel ~= "" then
--~     local cmd = "wcalc '" .. sel .. "'"
    -- note: just plain wcalc with scientific notation may truncate division!
    -- use -EE to force floating point, full numbers! (but from text..)
    local cmd = "wcalc " .. sel
    print(cmd)
    f = io.popen(cmd) -- runs command
    ret = f:read("*a") -- read output of command
    --~ 	remove returns
    ret=string.gsub(ret, "\n", "")
    editor:InsertText(oldse, ret) -- insert (print) output
    -- set the current cursor position after the insert
  -- CurrentPos sets selection
--~     editor.CurrentPos = oldse + string.len(ret)
  -- GotoPos - removes any selection
  editor:GotoPos(oldse + string.len(ret))
  end

end


function CQuote()
  -- quote character - '>'
  qch="// *"

  --~ 	retrieve selected region...
  oldss=editor.SelectionStart
  oldse=editor.SelectionEnd
  p1=editor:LineFromPosition(oldss);
  p2=editor:LineFromPosition(oldse);

  --~ 	if nothing selected, then take the line we are working on
  if p1==p2 then
    p2=p1+1
  end

  local sellines = {}
  for i=p1,p2-1 do
    line=editor:GetLine(i)

    line=string.gsub(line, "\n", "")
    line=string.gsub(line, "\r", "")

  line = qch .. " " .. line

    table.insert(sellines,table.getn(sellines)+1,line)
  end

  orets = ""
  for i=1,table.getn(sellines) do
    orets=orets .. sellines[i] .. "\n"
  end

  editor:ReplaceSel(orets)

  -- since the above kills selection, restore
  newss = editor:PositionFromLine(p1)
  newse = editor:PositionFromLine(p2)
  editor:SetSel(newss, newse)
end


function ExecSelText()
  --~ NOTE:
  --~ let "a=0" 2>&1 					# sh: let: not found
  --~ bash -c 'let "a=0" ; echo $a' 2>&1 	# 0
  --~ also: http://www.kilala.nl/Sysadmin/index.php?id=741 - The scope of variables in shell scripts: 1 3 6 10 Total is 0.

  --print(editor)
  oldss=editor.SelectionStart
  oldse=editor.SelectionEnd
  local selorig = editor:GetSelText()

  -- not equal is '~=', not '!=' or '<>'
  if (selorig ~= "") then
    -- now assign to global var
    --if (selorig:gmatch"^%s+") then -- "if match whitespace"? no
    -- one-liner check: lua -e 'ss="   "; print(ss:match"%S")' -- nil
    if not(selorig:match"%S") then -- "if not match not-whitespace"
      print ("Only whitespace in selection - resetting ExecSelText_command")
      ExecSelText_command = nil
    else
      print ("Setting ExecSelText_command to:")
      ExecSelText_command = selorig
      --print (ExecSelText_command)
    end
  end
  -- test of (ExecSelText_command) is (ExecSelText_command ~= nil)
  if ((ExecSelText_command) and (ExecSelText_command ~= "")) then
    -- local cmd = "mvs cnr " .. cfn .. "." .. cfe
    print(ExecSelText_command .. " 2>&1")
    -- using shell redirection here to get possible stderr (else lua-ex-api needed):
    local f = io.popen(ExecSelText_command  .. " 2>&1") -- runs command
    local l = f:read("*a") -- read output of command
    local se = io.stderr:read("*a")
    print(l, se)
    -- Re: stderr from an io.popen ? - http://lua-users.org/lists/lua-l/2010-09/msg00955.html
    -- lua-ex-api: http://lua-users.org/lists/lua-l/2010-09/msg00983.html;
    -- http://stackoverflow.com/questions/8838038/call-popen-with-environment
    -- print(io.stderr:flush()) -- "true"
    --editor:InsertText(oldse, "\n" .. l)
    --editor:GotoPos(oldse + string.len(l))
  else
    print("Command is empty", ExecSelText_command)
  end
end


function TerminalHere()
 os.execute("gnome-terminal --tab . &") -- tab doesn't work (only multiple --tab in single incantation)
end


function WordCount()
  local whiteSpace = 0;   --number of whitespace chars
  local nonEmptyLine = 0; --number of non blank lines
  local wordCount = 0;    --total number of words

  local sel = editor:GetSelText()
  -- not equal is '~=', not '!=' or '<>'
  if sel ~= "" then
    for word in string.gfind(sel, "%w+") do wordCount = wordCount + 1 end
    print("----------------------------");
    print("Words: \t\t",wordCount);
    return -- exit
  end

  --Calculate whitespace control
  for m in editor:match("\n") do
    whiteSpace = whiteSpace + 1;
  end
  for m in editor:match("\r") do
    whiteSpace = whiteSpace + 1;
  end
  for m in editor:match("\t") do --count tabs
    whiteSpace = whiteSpace + 1;
  end

  --Calculate non-empty lines and word count
  local itt = 0;
  while itt < editor.LineCount do --iterate through each line
    local hasChar, hasNum = 0;
    line = editor:GetLine(itt);
    if line then
      hasAlphaNum = string.find(line,'%w');
    end

    if (hasAlphaNum ~= nill) then
      nonEmptyLine = nonEmptyLine + 1;
    end

    if line then
      for word in string.gfind(line, "%w+") do wordCount = wordCount + 1 end
    end

    itt = itt + 1;
  end

  print("----------------------------");
  print("Chars: \t\t",(editor.Length) - whiteSpace);
  print("Words: \t\t",wordCount);
  print("Lines: \t\t",editor.LineCount);
  print("Lines(non-blank): ", nonEmptyLine);

end


function CleanTemp()
  --~ 	retrieve selected region...
  local oldss=editor.SelectionStart
  local oldse=editor.SelectionEnd
  local p1=editor:LineFromPosition(oldss);
  local p2=editor:LineFromPosition(oldse);

  editor:BeginUndoAction()

    local sel = editor:GetSelText()
    local clnd = sel

    clnd = string.gsub(clnd, "~}", "} ")
    clnd = string.gsub(clnd, "ff~", "ff")
    clnd = string.gsub(clnd, "fi~", "fi")
    clnd = string.gsub(clnd, "Th ~~", "Th")
--~     clnd = string.gsub(clnd, "[%s]+", " ") -- this also removes \n
    clnd = string.gsub(clnd, "~", " ")
    clnd = string.gsub(clnd, "[\ \t]+", " ") -- better than "[% %t]+"

    editor:ReplaceSel(clnd)
--~     editor:AutoCSelect(clnd)
    local newss = editor:PositionFromLine(p1)
    local newse = editor:PositionFromLine(p2)
    editor:SetSel(newss, newse)

  editor:EndUndoAction()
end

-- http://www.autoitscript.com/forum/topic/136111-scite-delete-comment-lines-or-hide-them-temporary/
--------------------------------------------------------------------------------
-- CommentsDelHide()
--
-- Hide (default) or delete comment lines in opened AutoIt-script in SciTE
--
-- Hided comments will shown again with reload file (menu file) or change to another tab and back
--
-- PARAMAETER..[optional]..: _fDelete - false=HIDE COMMENT-LINES (default) / true=DELETE COMMENT-LINES
--------------------------------------------------------------------------------
function CommentsDelHide(_fDelete)
	if _fDelete == nil then _fDelete = false end
	local function IsComment(pos) local tComment = {1,2}
    print(tComment[editor.StyleAt[pos]])
    if tComment[editor.StyleAt[pos]] == nil then return false else return true end
  end
	local function IsWS(pos) if editor.StyleAt[pos] == 0 then return true else return false end end
	local function GetRange(tTable)
		local tRange = {} iStart = ''
		if table.getn(tTable) == 0 then return nil end
		for i = 1, table.getn(tTable) do
			if iStart == '' then iStart = tTable[i] end
			if i < table.getn(tTable) then
				if tTable[i+1] ~= tTable[i] +1 then table.insert(tRange, {iStart, tTable[i]}) iStart = '' else
					if i+1 == table.getn(tTable) then table.insert(tRange, {iStart, tTable[i+1]}) break end end
			else table.insert(tRange, {tTable[i], tTable[i]}) end
		end
		return tRange
	end
	local function PreZero(sText, iMax) return string.rep('0', iMax - string.len(sText))..sText end
	editor:GotoLine(0)
	local n = 0
	local tCommLines = {}
	while editor.LineCount > n do
		editor:GotoLine(n)
		if IsComment(editor.CurrentPos) then
			table.insert(tCommLines, n)
		elseif IsWS(editor.CurrentPos) then
			editor:WordRight()
			if IsComment(editor.CurrentPos) then
				n = editor:LineFromPosition(editor.CurrentPos)
				table.insert(tCommLines, n)
			end
		end
		n = n +1
	end
	editor:BeginUndoAction()
	if _fDelete then
		if table.getn(tCommLines) > 0 then
			for i = table.getn(tCommLines), 1, -1 do
				editor:GotoLine(tCommLines[i])
				editor:LineDelete()
			end
		else
			print('!++ NO COMMENT LINES DETECT ++')
		end
	else
		local tRanges = GetRange(tCommLines)
		if tRanges == nil then print('!++ NO COMMENT LINES DETECT ++') end
		local max = string.len(tRanges[table.getn(tRanges)][2])
		for i = 1, table.getn(tRanges) do
			print('++ HIDE LINE'..'....'..PreZero(tostring(tRanges[i][1] +1), max)..' TO '..PreZero(tostring(tRanges[i][2] +1), max)..' ++')
			editor:HideLines(tRanges[i][1],tRanges[i][2])
		end
	end
	editor:EndUndoAction()
end  -- CommentsDelHide()

function CommentsHide()
	CommentsDelHide()
end

function CommentsDelete()
	CommentsDelHide(true)
end

function DelTilde() -- copy of EQuotePlusOne
  --~ 	retrieve selected region...
  oldss=editor.SelectionStart
  oldse=editor.SelectionEnd
  p1=editor:LineFromPosition(oldss);
  p2=editor:LineFromPosition(oldse);
  --~ 	if nothing selected, then take the line we are working on
  if p1==p2 then
    p2=p1+1
  end
  --~ 	read the lines in the selection to an array
  local sellines = {}
  --~ 	add the text
  for i=p1,p2-1 do -- was: start_line,end_line-1
    line=editor:GetLine(i)
    --~ 		remove returns, and the tilde
    line=string.gsub(line, "\n", "")
    line=string.gsub(line, "\r", "")
    line=string.gsub(line, "~", "")
    table.insert(sellines,table.getn(sellines)+1,line)
  end
  --~ 	format the text...
  orets = ""
  for i=1,table.getn(sellines) do
    orets=orets..sellines[i].."\n"
  end
  --~ 	and replace!
  editor:ReplaceSel(orets)
  -- since the above kills selection, restore
  -- so recalc new selection points based on line start
  newss = editor:PositionFromLine(p1)
  newse = editor:PositionFromLine(p2)
  editor:SetSel(newss, newse)
end

