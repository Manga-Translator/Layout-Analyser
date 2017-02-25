/*
% NOTES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 next steps:
 
 -turn blobs into groups based on dimensions
    -must be tolerant of merging/splitting/missing/poorly-bounded characters
 -test for small surrounding blobs to be added (otherwise, punctuation will fail the whitespace test)
 -test for surrounding whitespace with more stringent b/w conversion
 -scan for whitespace bounds
    -extend until hit too-large blob, retract 1/2 way to farthest char bound (only good for rectangular bubbles)?
    -generate a mask from too-large blobs, and apply to origional picture?

 %%small to-do list%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
 
 enable scanning on diagonals to enable better detection of character blobs (blob merging now less of an issue)
 extend level differentiation to anti-noise (possible redesign/repeated passes)?
 take neghbours into account when determing level
 implement percentage blob clasification
    
 remember to add minimum whitespace to extracted text for tesseract
    -could scale text for tesseract, knowing tesseract's optimal pixel width per character
 
 write a bitmap color analyser
 
 %%old notes%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
 possible extra class for very small blobs to separate elipses
   -they can still be included if near a character (larger blob, but can otherwise be ignored)
 
 bounding boxes for each blob
   -could drop noise filtering, which corrodes text, since scanning is faster
   X-test for squareness of aspect ratio (+/- 50% ?)
     X-can't as some characters get merged
   ?-test for alignment
     ?-signal to noise in spacing is an issue

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/
%typedef
type blobBounds :
    record
	minX : int
	maxX : int
	minY : int
	maxY : int
	size : int
    end record
    
%init
var picID, width, height : int
var fileName, settings : string
%fileName := "test1.jpg"
%fileName := "savepoint.bmp"
fileName := "blobs3.bmp"
picID := Pic.FileNew (fileName)

var debugWindow : int := 0
Window.SetActive(0)
var debugFile : int := -1

proc debug(text:string)
    %var temp : int := Window.GetSelect
    
    %if debugWindow = 0 then
    %    debugWindow := Window.Open("title:Debug Window")
    %end if
    
    if debugFile = -1 then
	open(debugFile, "DebugLog.txt", "w")
    end if
    
    %Window.SetActive(debugWindow)
    %put text ..
    put : debugFile, text ..
    
    %Window.SetActive(temp)
end debug

%b/w-ization-ifyer V2
function checkLevel2(x, y, thresh : int) : int
    var pixel : int := View.WhatDotColor(x,y)
    var level : int
    
    if pixel = 7 then
	level := 0
    elsif pixel = 15 then
	level := 9
    elsif pixel = 8 then
	level := 14
    elsif pixel = 0 then
	level := 17
    elsif pixel >= 16 and pixel <= 24 then
	level := pixel - 16
    elsif pixel >= 25 and pixel <= 28 then
	level := pixel - 15
    elsif pixel >= 29 and pixel <= 31 then
	level := pixel - 14
    else
	debug(chr(10) + "Unrecognised color detected (" + intstr(pixel) + ") at (" + intstr(x) + "," + intstr(y) + ")" + chr(10))
	break
	level := 17 %default white (questionable but sometimes nessisary in testing)
    end if
    
    var threshold : int := 15
    
    if level >= threshold then
	result white
    else
	result black
    end if 
end checkLevel2

function checkNoise3(x, y : int) : int
    %version 2 ignores white noise, prefering black noise as seen around text
    var score : int := 0
    
    var threshold : int := 6

    if View.WhatDotColor(x,y) = white then
	result white
    end if
    
    if View.WhatDotColor(x+1,y) = white then
	score := score +1
    end if
    if View.WhatDotColor(x-1,y) = white then
	score := score +1
    end if
    if View.WhatDotColor(x,y+1) = white then
	score := score +1
    end if
    if View.WhatDotColor(x,y-1) = white then
	score := score +1
    end if
    if View.WhatDotColor(x+1,y+1) = white then
	score := score +1
    end if
    if View.WhatDotColor(x-1,y-1) = white then
	score := score +1
    end if
    if View.WhatDotColor(x+1,y-1) = white then
	score := score +1
    end if
    if View.WhatDotColor(x-1,y+1) = white then
	score := score +1
    end if
    if (score >= threshold) then
	result white
    else
	result black
    end if
end checkNoise3

/*
proc drawText(text : string, x,y : int)
    var font : int := Font.New ("serif:12")
    var width := length(text)*8
    Draw.FillBox(x,y,x+width,y+16,white)
    Draw.Text(text,x,y,font,black)
end drawText
*/

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%start of program
if picID = 0 then
    put "error opening file"
else
    %prep for picture
    width := Pic.Width(picID)
    height := Pic.Height(picID)

    settings := "graphics:" + intstr(width) + ";" + intstr(height)
    View.Set (settings)
    
    %Draw.Fill (0, 0, white, yellow)
    
    %draw picture
    Pic.Draw(picID, 0, 0, picCopy)
    /*
    %b/w-ize picture (we don't care beyond white and not-white pixels)
    for j : 0 .. height
	for i : 0 .. width
	    Draw.Dot(i, j, checkLevel2(i, j, 0))
	end for
    end for
    
    %remove noise
    for j : 0 .. height
	for i : 0 .. width
	    Draw.Dot(i, j, checkNoise3(i, j))
	end for
    end for
    */
    /*
    %test for blobs
    var total : int
    var blobMinx,blobMiny,blobMaxx,blobMaxy : int
    var found : boolean
    */
    var minBlobSize : int := 20
    var maxBlobSize : int := 1000
    /*
    var boundingBoxes : flexible array 1 .. 0 of blobBounds
    var tempBounds : blobBounds
    var numBoxes : int := 1
    
    for j : 0 .. height
	for i : 0 .. width
	    %new canidate start pixel
	    
	    %pixel is black (undiscovered)
	    if View.WhatDotColor(i,j) = black then
		%start of new blob
		total := 1
		
		%new seed blue pixel
		Draw.Dot(i,j,brightblue)
		blobMinx := i
		blobMaxx := i
		blobMiny := j
		blobMaxy := j
		
		%put "S" .. 
	    
		%series of scans to add to blob
		loop
		    found := false
		
		    %scan for new black pixels to add
		    for m : (blobMiny -1) .. (blobMaxy +1)
			for n : (blobMinx -1) .. (blobMaxx +1)
			    %if black and a neghbour of blue
			    if View.WhatDotColor(n,m) = black then
				if (
				    View.WhatDotColor(n+1,m) = brightblue or
				    View.WhatDotColor(n,m+1) = brightblue or
				    View.WhatDotColor(n-1,m) = brightblue or
				    View.WhatDotColor(n,m-1) = brightblue
				) then
				    Draw.Dot(n,m,brightblue)
				    total := total +1
				    
				    if not total > maxBlobSize then
					blobMinx := min(blobMinx,n)
					blobMaxx := max(blobMaxx,n)
					blobMiny := min(blobMiny,m)
					blobMaxy := max(blobMaxy,m)
				    end if
				    
				    found := true
				end if
			    end if
			end for
		    end for
		    
		    if found = true then
			for decreasing m : (blobMaxy +1) .. (blobMiny -1)
			    for n : (blobMinx -1) .. (blobMaxx +1)
				%if black and a neghbour of blue
				if View.WhatDotColor(n,m) = black then
				    if (
					View.WhatDotColor(n+1,m) = brightblue or
					View.WhatDotColor(n,m+1) = brightblue or
					View.WhatDotColor(n-1,m) = brightblue or
					View.WhatDotColor(n,m-1) = brightblue
				    ) then
					Draw.Dot(n,m,brightblue)
					total := total +1
					
					if not total > maxBlobSize then
					    blobMinx := min(blobMinx,n)
					    blobMaxx := max(blobMaxx,n)
					    blobMiny := min(blobMiny,m)
					    blobMaxy := max(blobMaxy,m)
					end if
					
					found := true
				    end if
				end if
			    end for
			end for
		    
			for m : (blobMiny -1) .. (blobMaxy +1)
			    for decreasing n : (blobMaxx +1) .. (blobMinx -1)
				%if black and a neghbour of blue
				if View.WhatDotColor(n,m) = black then
				    if (
					View.WhatDotColor(n+1,m) = brightblue or
					View.WhatDotColor(n,m+1) = brightblue or
					View.WhatDotColor(n-1,m) = brightblue or
					View.WhatDotColor(n,m-1) = brightblue
				    ) then
					Draw.Dot(n,m,brightblue)
					total := total +1
					
					if not total > maxBlobSize then
					    blobMinx := min(blobMinx,n)
					    blobMaxx := max(blobMaxx,n)
					    blobMiny := min(blobMiny,m)
					    blobMaxy := max(blobMaxy,m)
					end if
					
					found := true
				    end if
				end if
			    end for
			end for
		    
			for decreasing m : (blobMaxy +1) .. (blobMiny -1)
			    for decreasing n : (blobMaxx +1) .. (blobMinx -1)
				%if black and a neghbour of blue
				if View.WhatDotColor(n,m) = black then
				    if (
					View.WhatDotColor(n+1,m) = brightblue or
					View.WhatDotColor(n,m+1) = brightblue or
					View.WhatDotColor(n-1,m) = brightblue or
					View.WhatDotColor(n,m-1) = brightblue
				    ) then
					Draw.Dot(n,m,brightblue)
					total := total +1
					
					if not total > maxBlobSize then
					    blobMinx := min(blobMinx,n)
					    blobMaxx := max(blobMaxx,n)
					    blobMiny := min(blobMiny,m)
					    blobMaxy := max(blobMaxy,m)
					end if
					
					found := true
				    end if
				end if
			    end for
			end for
			
			if total > maxBlobSize then
			    blobMinx := 1
			    blobMiny := 1
			    blobMaxx := maxx -1
			    blobMaxy := maxy -1
			end if
			
		    end if
		
		    if found = false then
			exit
		    end if
		end loop
		%have found all of this blob
		
		%recolor depending on type
		if total > maxBlobSize then
		    %recolor from blue to appropriate color
		    for m : 0 .. height
			for n : 0 .. width
			    if View.WhatDotColor(n,m) = brightblue then
				Draw.Dot(n,m,red)
			    end if
			end for
		    end for
		else
		    if total < minBlobSize and total not = 0 then
			%recolor from blue to appropriate color
			for m : 0 .. height
			    for n : 0 .. width
				if View.WhatDotColor(n,m) = brightblue then
				    Draw.Dot(n,m,brightred)
				end if
			    end for
			end for
		    else
			%debug("x:" + intstr(blobMinx,3) + "-" + intstr(blobMaxx,3) + "\ty:" + intstr(blobMiny,3) + "-" + intstr(blobMaxy,3) + "\tt:" + intstr(total) + chr(10))
			
			tempBounds.minX := blobMinx
			tempBounds.maxX := blobMaxx
			tempBounds.minY := blobMiny
			tempBounds.maxY := blobMaxy
			tempBounds.size := total

			new boundingBoxes, numBoxes
			boundingBoxes(numBoxes) := tempBounds
			numBoxes := numBoxes +1
			
			%recolor from blue to appropriate color
			if total not = 0 then
			    for m : 0 .. height
				for n : 0 .. width
				    if View.WhatDotColor(n,m) = brightblue then
					Draw.Dot(n,m,brightgreen)
				    end if
				end for
			    end for
			end if
		    end if
		end if
		
		
		
		%recolor blob to avoid redetection
		for m : 0 .. height
		    for n : 0 .. width
			if View.WhatDotColor(n,m) = brightblue then
			    Draw.Dot(n,m,green)
			end if
		    end for
		end for
		
		
		%debug("Blob total: " + intstr(total) + chr(10))
		%debug(intstr(total) + " ")
		
	    end if
	end for
    end for
    */
    %Draw.Fill(0,0,black,brightgreen)
    
    %preload program for savepoint
    var numBoxes := 46
    var boundingBoxes : array 1 .. 45 of blobBounds := init (
	init (241,245,1,9,23),
	init (208,219,22,33,94),
	init (207,219,35,60,215),
	init (285,292,35,43,33),
	init (285,294,46,55,48),
    
	init (284,294,57,67,88),
	init (209,218,62,74,69),
	init (302,306,63,71,25),
	init (146,150,70,77,23),
	init (286,293,72,78,37),
    
	init (40,54,73,88,85),
	init (301,309,75,84,46),
	init (285,294,80,90,86),
	init (188,197,88,92,24),
	init (299,309,92,101,60),
    
	init (48,55,95,105,29),
	init (270,280,103,113,100),
	init (284,295,103,125,195),
	init (299,304,104,113,28),
	init (306,308,104,113,23),
    
    
	init (46,54,114,126,48),
	init (272,280,115,124,36),
	init (299,309,115,124,96),
	init (361,369,117,124,31),
	init (143,147,118,126,21),
    
	init (360,368,131,136,30),
	init (43,54,133,142,38),
	init (298,307,146,154,48),
	init (316,322,146,155,35),
	init (40,55,152,168,99),
    
	init (299,305,157,166,28),
	init (340,360,166,183,216),
	init (299,306,169,177,28),
	init (313,321,169,177,39),
	init (359,367,170,174,26),
    
	init (38,44,173,186,35),
	init (48,55,173,185,38),
	init (298,307,180,189,41),
	init (313,321,180,190,68),
	init (40,53,192,207,65),
    
    
	init (38,54,212,227,97),
	init (162,168,231,264,130),
	init (38,43,232,245,38),
	init (46,54,232,246,60),
	init (40,53,252,264,63) 
    )

    Pic.Draw(Pic.FileNew ("test1.jpg"), 0, 0, picCopy)
    
    /*
    for m : 0 .. height
	for n : 0 .. width
	    if View.WhatDotColor(n,m) = red or View.WhatDotColor(n,m) = brightred then
		Draw.Dot(n,m,white)
	    end if
	end for
    end for
    */
    
    for num : 1 .. numBoxes-1
	if (boundingBoxes(num).size >= minBlobSize) and (boundingBoxes(num).size <= maxBlobSize) then
	    Draw.Box(boundingBoxes(num).minX,boundingBoxes(num).minY,boundingBoxes(num).maxX,boundingBoxes(num).maxY,purple)
	end if
    end for
    
    debug(chr(10) + "Millis: " + intstr(Time.ElapsedCPU) + chr(10))
    
    for num : 1 .. numBoxes-1
	debug("x:" + intstr(boundingBoxes(num).minX,3) + "-" + intstr(boundingBoxes(num).maxX,3) + "\ty:" + intstr(boundingBoxes(num).minY,3) + "-" + intstr(boundingBoxes(num).maxY,3) + "\tt:" + intstr(boundingBoxes(num).size) + chr(10))
    end for
    
end if
