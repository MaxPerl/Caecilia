# By George Peter Staplin
# See also the README for a list of contributors
# RCS: @(#) $Id: ctextAdvanced.tcl,v 1.9 2011/04/18 19:49:48 andreas_kupries Exp $

package require Tk
package provide ctextAdvanced 3.3

namespace eval ctextAdvanced {}

#win is used as a unique token to create arrays for each ctextAdvanced instance
proc ctextAdvanced::getAr {win suffix name} {
    set arName __ctextAdvanced[set win][set suffix]
    uplevel [list upvar \#0 $arName $name]
    return $arName
}

proc ctextAdvanced {win args} {
    if {[llength $args] & 1} {
	return -code error \
	    "invalid number of arguments given to ctextAdvanced (uneven number after window) : $args"
    }

    frame $win -class Ctext

    set tmp [text .__ctextAdvancedTemp]

    ctextAdvanced::getAr $win config ar

    set ar(-fg) [$tmp cget -foreground]
    set ar(-bg) [$tmp cget -background]
    set ar(-font) [$tmp cget -font]
    set ar(-linemap_font_select) [$tmp cget -font]
    set ar(-relief) [$tmp cget -relief]
    destroy $tmp
    set ar(-yscrollcommand) ""
    set ar(-linemap) 1
    set ar(-linemapfg) $ar(-fg)
    set ar(-linemapbg) $ar(-bg)
    set ar(-linemap_mark_command) {}
    set ar(-linemap_markable) 1
    set ar(-linemap_select_fg) black
    set ar(-linemap_select_bg) yellow
    set ar(-highlight) 1
    set ar(win) $win
    set ar(modified) 0
    set ar(commentsAfterId) ""
    set ar(highlightAfterId) ""
    set ar(blinkAfterId) ""

    set ar(ctextAdvancedFlags) [list -yscrollcommand -linemap -linemapfg -linemapbg \
			    -font -linemap_mark_command -highlight -linemap_markable \
			    -linemap_select_fg -linemap_font_select \
			    -linemap_select_bg]

    array set ar $args

    foreach flag {foreground background} short {fg bg} {
	if {[info exists ar(-$flag)] == 1} {
	    set ar(-$short) $ar(-$flag)
	    unset ar(-$flag)
	}
    }

    # Now remove flags that will confuse text and those that need
    # modification:
    foreach arg $ar(ctextAdvancedFlags) {
	if {[set loc [lsearch $args $arg]] >= 0} {
	    set args [lreplace $args $loc [expr {$loc + 1}]]
	}
    }

    set args [concat $args [list -yscrollcommand \
				[list ctextAdvanced::event:yscroll $win $ar(-yscrollcommand)]]]
	
	canvas $win.canvas \
        -width 40 \
        -highlightthickness 0
    
    #$win.canvas itemconfigure numbers -font $ar(-font) -foreground $ar(-linemapfg)
    $win.canvas configure -background $ar(-linemapbg) -takefocus 0 \
    	-relief $ar(-relief)
    
    #escape $win, because it could have a space
    eval text \$win.t -font \$ar(-font) $args

	if {$ar(-linemap) == 1} {
		pack $win.canvas -side left -fill y
    }
    pack $win.t -side left -fill both -expand true	
	
    rename $win __ctextAdvancedJunk$win
    rename $win.t $win._t

    bind $win <Destroy> [list ctextAdvanced::event:Destroy $win %W]
    bindtags $win.t [linsert [bindtags $win.t] 0 $win]

    interp alias {} $win {} ctextAdvanced::instanceCmd $win
    interp alias {} $win.t {} $win

    # If the user wants C comments they should call
    # ctextAdvanced::enableComments
    ctextAdvanced::disableComments $win
    ctextAdvanced::modified $win 0
    ctextAdvanced::buildArgParseTable $win
	
	# Arrange for line numbers to be redrawn when just about anything
    # happens to the text widget. This runs much faster than you might
    # think.
    trace add execution $win leave [list ctextAdvanced::traceCallback $win $win.canvas $ar(-font)]
    bind $win.t <Configure> [list ctextAdvanced::traceCallback $win $win.canvas $ar(-font)]

    return $win
}

proc ctextAdvanced::event:yscroll {win clientData args} {
    
    if {$clientData == ""} {
	return
    }
    uplevel \#0 $clientData $args
}

proc ctextAdvanced::event:Destroy {win dWin} {
    if {![string equal $win $dWin]} {
	return
    }

    ctextAdvanced::getAr $win config configAr

    catch {after cancel $configAr(commentsAfterId)}
    catch {after cancel $configAr(highlightAfterId)}
    catch {after cancel $configAr(blinkAfterId)}

    catch {rename $win {}}
    interp alias {} $win.t {}
    ctextAdvanced::clearHighlightClasses $win
    array unset [ctextAdvanced::getAr $win config ar]
}

# This stores the arg table within the config array for each instance.
# It's used by the configure instance command.
proc ctextAdvanced::buildArgParseTable win {
    set argTable [list]

    lappend argTable any -linemap_mark_command {
	set configAr(-linemap_mark_command) $value
	break
    }

    lappend argTable {1 true yes} -linemap {
	pack forget $self.t
	pack $self.canvas -side left -fill y
	pack $self.t -side left -fill both -expand true
	set configAr(-linemap) 1
	break
    }

    lappend argTable {0 false no} -linemap {
	pack forget $self.canvas
	set configAr(-linemap) 0
	break
    }

    lappend argTable any -yscrollcommand {
	set cmd [list $self._t config -yscrollcommand \
		     [list ctextAdvanced::event:yscroll $self $value]]

	if {[catch $cmd res]} {
	    return $res
	}
	set configAr(-yscrollcommand) $value
	break
    }

    lappend argTable any -linemapfg {
	if {[catch {winfo rgb $self $value} res]} {
	    return -code error $res
	}
	#$self.l config -fg $value
	set configAr(-linemapfg) $value
	break
    }

    lappend argTable any -linemapbg {
	if {[catch {winfo rgb $self $value} res]} {
	    return -code error $res
	}
	#$self.l config -bg $value
	set configAr(-linemapbg) $value
	break
    }

    lappend argTable any -font {
	if {[catch {$self.canvas config -font $value} res]} {
	    return -code error $res
	}
	$self._t config -font $value
	set configAr(-font) $value
	break
    }
    
    lappend argTable any -linemap_font_select {
	if {[catch {$self.canvas config -font $value} res]} {
	    return -code error $res
	}
	set configAr(-linemap_font_select) $value
	break
    }

    lappend argTable {0 false no} -highlight {
	set configAr(-highlight) 0
	break
    }

    lappend argTable {1 true yes} -highlight {
	set configAr(-highlight) 1
	break
    }

    lappend argTable {0 false no} -linemap_markable {
	set configAr(-linemap_markable) 0
	break
    }

    lappend argTable {1 true yes} -linemap_markable {
	set configAr(-linemap_markable) 1
	break
    }

    lappend argTable any -linemap_select_fg {
	if {[catch {winfo rgb $self $value} res]} {
	    return -code error $res
	}
	set configAr(-linemap_select_fg) $value
	#$self.l tag configure lmark -foreground $value
	break
    }

    lappend argTable any -linemap_select_bg {
	if {[catch {winfo rgb $self $value} res]} {
	    return -code error $res
	}
	set configAr(-linemap_select_bg) $value
	#$self.l tag configure lmark -background $value
	break
    }

    ctextAdvanced::getAr $win config ar
    set ar(argTable) $argTable
}

proc ctextAdvanced::commentsAfterIdle {win} {
    ctextAdvanced::getAr $win config configAr

    if {"" eq $configAr(commentsAfterId)} {
	set configAr(commentsAfterId) [after idle \
	   [list ctextAdvanced::comments $win [set afterTriggered 1]]]
    }
}

proc ctextAdvanced::highlightAfterIdle {win lineStart lineEnd} {
    ctextAdvanced::getAr $win config configAr

    if {"" eq $configAr(highlightAfterId)} {
	set configAr(highlightAfterId) [after idle \
	    [list ctextAdvanced::highlight $win $lineStart $lineEnd [set afterTriggered 1]]]
    }
}

proc ctextAdvanced::instanceCmd {self cmd args} {
    #slightly different than the RE used in ctextAdvanced::comments
    set commentRE {\"|\\|'|/|\*}

    switch -glob -- $cmd {
	append {
	    if {[catch {$self._t get sel.first sel.last} data] == 0} {
		clipboard append -displayof $self $data
	    }
	}

	cget {
	    set arg [lindex $args 0]
	    ctextAdvanced::getAr $self config configAr

	    foreach flag $configAr(ctextAdvancedFlags) {
		if {[string match ${arg}* $flag]} {
		    return [set configAr($flag)]
		}
	    }
	    return [$self._t cget $arg]
	}

	conf* {
	    ctextAdvanced::getAr $self config configAr

	    if {0 == [llength $args]} {
		set res [$self._t configure]
		set del [lsearch -glob $res -yscrollcommand*]
		set res [lreplace $res $del $del]
		foreach flag $configAr(ctextAdvancedFlags) {
		    lappend res [list $flag [set configAr($flag)]]
		}
		return $res
	    }

	    array set flags {}
	    foreach flag $configAr(ctextAdvancedFlags) {
		set loc [lsearch $args $flag]
		if {$loc < 0} {
		    continue
		}

		if {[llength $args] <= ($loc + 1)} {
		    #.t config -flag
		    return [set configAr($flag)]
		}

		set flagArg [lindex $args [expr {$loc + 1}]]
		set args [lreplace $args $loc [expr {$loc + 1}]]
		set flags($flag) $flagArg
	    }

	    foreach {valueList flag cmd} $configAr(argTable) {
		if {[info exists flags($flag)]} {
		    foreach valueToCheckFor $valueList {
			set value [set flags($flag)]
			if {[string equal "any" $valueToCheckFor]} $cmd \
			    elseif {[string equal $valueToCheckFor [set flags($flag)]]} $cmd
		    }
		}
	    }

	    if {[llength $args]} {
		#we take care of configure without args at the top of this branch
		uplevel 1 [linsert $args 0 $self._t configure]
	    }
	}

	copy {
	    tk_textCopy $self
	}

	cut {
	    if {[catch {$self.t get sel.first sel.last} data] == 0} {
		clipboard clear -displayof $self.t
		clipboard append -displayof $self.t $data
		$self delete [$self.t index sel.first] [$self.t index sel.last]
		ctextAdvanced::modified $self 1
	    }
	}

	delete {
	    #delete n.n ?n.n

	    set argsLength [llength $args]

	    #first deal with delete n.n
	    if {$argsLength == 1} {
		set deletePos [lindex $args 0]
		set prevChar [$self._t get $deletePos]

		$self._t delete $deletePos
		set char [$self._t get $deletePos]

		set prevSpace [ctextAdvanced::findPreviousSpace $self._t $deletePos]
		set nextSpace [ctextAdvanced::findNextSpace $self._t $deletePos]

		set lineStart [$self._t index "$deletePos linestart"]
		set lineEnd [$self._t index "$deletePos + 1 chars lineend"]

		#This pattern was used in 3.1.  We may want to investigate using it again
		#eventually to reduce flicker.  It caused a bug with some patterns.
		#if {[string equal $prevChar "#"] || [string equal $char "#"]} {
		#	set removeStart $lineStart
		#	set removeEnd $lineEnd
		#} else {
		#	set removeStart $prevSpace
		#	set removeEnd $nextSpace
		#}
		set removeStart $lineStart
		set removeEnd $lineEnd

		foreach tag [$self._t tag names] {
		    if {[string equal $tag "_cComment"] != 1} {
			$self._t tag remove $tag $removeStart $removeEnd
		    }
		}

		set checkStr "$prevChar[set char]"

		if {[regexp $commentRE $checkStr]} {
		    ctextAdvanced::commentsAfterIdle $self
		}

		ctextAdvanced::highlightAfterIdle $self $lineStart $lineEnd
	    } elseif {$argsLength == 2} {
		#now deal with delete n.n ?n.n?
		set deleteStartPos [lindex $args 0]
		set deleteEndPos [lindex $args 1]

		set data [$self._t get $deleteStartPos $deleteEndPos]

		set lineStart [$self._t index "$deleteStartPos linestart"]
		set lineEnd [$self._t index "$deleteEndPos + 1 chars lineend"]
		eval \$self._t delete $args

		foreach tag [$self._t tag names] {
		    if {[string equal $tag "_cComment"] != 1} {
			$self._t tag remove $tag $lineStart $lineEnd
		    }
		}

		if {[regexp $commentRE $data]} {
		    ctextAdvanced::commentsAfterIdle $self
		}

		ctextAdvanced::highlightAfterIdle $self $lineStart $lineEnd
		if {[string first "\n" $data] >= 0} {
		    
		}
	    } else {
		return -code error "invalid argument(s) sent to $self delete: $args"
	    }
	    ctextAdvanced::modified $self 1
	}

	fastdelete {
	    eval \$self._t delete $args
	    ctextAdvanced::modified $self 1
	    
	}

	fastinsert {
	    eval \$self._t insert $args
	    ctextAdvanced::modified $self 1
	    
	}

	highlight {
	    ctextAdvanced::highlight $self [lindex $args 0] [lindex $args 1]
	    ctextAdvanced::comments $self
	}

	insert {
	    if {[llength $args] < 2} {
		return -code error "please use at least 2 arguments to $self insert"
	    }

	    set insertPos [lindex $args 0]
	    set prevChar [$self._t get "$insertPos - 1 chars"]
	    set nextChar [$self._t get $insertPos]
	    set lineStart [$self._t index "$insertPos linestart"]
	    set prevSpace [ctextAdvanced::findPreviousSpace $self._t ${insertPos}-1c]
	    set data [lindex $args 1]
	    eval \$self._t insert $args

	    set nextSpace [ctextAdvanced::findNextSpace $self._t insert]
	    set lineEnd [$self._t index "insert lineend"]

	    if {[$self._t compare $prevSpace < $lineStart]} {
		set prevSpace $lineStart
	    }

	    if {[$self._t compare $nextSpace > $lineEnd]} {
		set nextSpace $lineEnd
	    }

	    foreach tag [$self._t tag names] {
		if {[string equal $tag "_cComment"] != 1} {
		    $self._t tag remove $tag $prevSpace $nextSpace
		}
	    }

	    set REData $prevChar
	    append REData $data
	    append REData $nextChar
	    if {[regexp $commentRE $REData]} {
		ctextAdvanced::commentsAfterIdle $self
	    }

	    ctextAdvanced::highlightAfterIdle $self $lineStart $lineEnd

	    switch -- $data {
		"\}" {
		    ctextAdvanced::matchPair $self "\\\{" "\\\}" "\\"
		}
		"\]" {
		    ctextAdvanced::matchPair $self "\\\[" "\\\]" "\\"
		}
		"\)" {
		    ctextAdvanced::matchPair $self "\\(" "\\)" ""
		}
		"\"" {
		    ctextAdvanced::matchQuote $self
		}
	    }
	    ctextAdvanced::modified $self 1
	    
	}

	paste {
	    tk_textPaste $self
	    ctextAdvanced::modified $self 1
	}

	edit {
	    set subCmd [lindex $args 0]
	    set argsLength [llength $args]

	    ctextAdvanced::getAr $self config ar

	    if {"modified" == $subCmd} {
		if {$argsLength == 1} {
		    return $ar(modified)
		} elseif {$argsLength == 2} {
		    set value [lindex $args 1]
		    set ar(modified) $value
		} else {
		    return -code error "invalid arg(s) to $self edit modified: $args"
		}
	    } else {
		#Tk 8.4 has other edit subcommands that I don't want to emulate.
		return [uplevel 1 [linsert $args 0 $self._t $cmd]]
	    }
	}

	default {
	    return [uplevel 1 [linsert $args 0 $self._t $cmd]]
	}
    }
}

proc ctextAdvanced::tag:blink {win count {afterTriggered 0}} {
    if {$count & 1} {
	$win tag configure __ctextAdvanced_blink \
	    -foreground [$win cget -bg] -background [$win cget -fg]
    } else {
	$win tag configure __ctextAdvanced_blink \
	    -foreground [$win cget -fg] -background [$win cget -bg]
    }

    ctextAdvanced::getAr $win config configAr
    if {$afterTriggered} {
	set configAr(blinkAfterId) ""
    }

    if {$count == 4} {
	$win tag delete __ctextAdvanced_blink 1.0 end
	return
    }

    incr count
    if {"" eq $configAr(blinkAfterId)} {
	set configAr(blinkAfterId) [after 50 \
		[list ctextAdvanced::tag:blink $win $count [set afterTriggered 1]]]
    }
}

proc ctextAdvanced::matchPair {win str1 str2 escape} {
    set prevChar [$win get "insert - 2 chars"]

    if {[string equal $prevChar $escape]} {
	#The char that we thought might be the end is actually escaped.
	return
    }

    set searchRE "[set str1]|[set str2]"
    set count 1

    set pos [$win index "insert - 1 chars"]
    set endPair $pos
    set lastFound ""
    while 1 {
	set found [$win search -backwards -regexp $searchRE $pos]

	if {$found == "" || [$win compare $found > $pos]} {
	    return
	}

	if {$lastFound != "" && [$win compare $found == $lastFound]} {
	    #The search wrapped and found the previous search
	    return
	}

	set lastFound $found
	set char [$win get $found]
	set prevChar [$win get "$found - 1 chars"]
	set pos $found

	if {[string equal $prevChar $escape]} {
	    continue
	} elseif {[string equal $char [subst $str2]]} {
	    incr count
	} elseif {[string equal $char [subst $str1]]} {
	    incr count -1
	    if {$count == 0} {
		set startPair $found
		break
	    }
	} else {
	    # This shouldn't happen.  I may in the future make it
	    # return -code error
	    puts stderr "ctextAdvanced seems to have encountered a bug in ctextAdvanced::matchPair"
	    return
	}
    }

    $win tag add __ctextAdvanced_blink $startPair
    $win tag add __ctextAdvanced_blink $endPair
    ctextAdvanced::tag:blink $win 0
}

proc ctextAdvanced::matchQuote {win} {
    set endQuote [$win index insert]
    set start [$win index "insert - 1 chars"]

    if {[$win get "$start - 1 chars"] == "\\"} {
	#the quote really isn't the end
	return
    }
    set lastFound ""
    while 1 {
	set startQuote [$win search -backwards \" $start]
	if {$startQuote == "" || [$win compare $startQuote > $start]} {
	    #The search found nothing or it wrapped.
	    return
	}

	if {$lastFound != "" && [$win compare $lastFound == $startQuote]} {
	    #We found the character we found before, so it wrapped.
	    return
	}
	set lastFound $startQuote
	set start [$win index "$startQuote - 1 chars"]
	set prevChar [$win get $start]

	if {$prevChar == "\\"} {
	    continue
	}
	break
    }

    if {[$win compare $endQuote == $startQuote]} {
	#probably just \"
	return
    }

    $win tag add __ctextAdvanced_blink $startQuote $endQuote
    ctextAdvanced::tag:blink $win 0
}

proc ctextAdvanced::enableComments {win} {
    $win tag configure _cComment -foreground khaki
}
proc ctextAdvanced::disableComments {win} {
    catch {$win tag delete _cComment}
}

proc ctextAdvanced::comments {win {afterTriggered 0}} {
    if {[catch {$win tag cget _cComment -foreground}]} {
	#C comments are disabled
	return
    }

    if {$afterTriggered} {
	ctextAdvanced::getAr $win config configAr
	set configAr(commentsAfterId) ""
    }

    set startIndex 1.0
    set commentRE {\\\\|\"|\\\"|\\'|'|/\*|\*/}
    set commentStart 0
    set isQuote 0
    set isSingleQuote 0
    set isComment 0
    $win tag remove _cComment 1.0 end
    while 1 {
	set index [$win search -count length -regexp $commentRE $startIndex end]

	if {$index == ""} {
	    break
	}

	set endIndex [$win index "$index + $length chars"]
	set str [$win get $index $endIndex]
	set startIndex $endIndex

	if {$str == "\\\\"} {
	    continue
	} elseif {$str == "\\\""} {
	    continue
	} elseif {$str == "\\'"} {
	    continue
	} elseif {$str == "\"" && $isComment == 0 && $isSingleQuote == 0} {
	    if {$isQuote} {
		set isQuote 0
	    } else {
		set isQuote 1
	    }
	} elseif {$str == "'" && $isComment == 0 && $isQuote == 0} {
	    if {$isSingleQuote} {
		set isSingleQuote 0
	    } else {
		set isSingleQuote 1
	    }
	} elseif {$str == "/*" && $isQuote == 0 && $isSingleQuote == 0} {
	    if {$isComment} {
		#comment in comment
		break
	    } else {
		set isComment 1
		set commentStart $index
	    }
	} elseif {$str == "*/" && $isQuote == 0 && $isSingleQuote == 0} {
	    if {$isComment} {
		set isComment 0
		$win tag add _cComment $commentStart $endIndex
		$win tag raise _cComment
	    } else {
		#comment end without beginning
		break
	    }
	}
    }
}

proc ctextAdvanced::addHighlightClass {win class color keywords} {
    set ref [ctextAdvanced::getAr $win highlight ar]
    foreach word $keywords {
	set ar($word) [list $class $color]
    }
    $win tag configure $class

    ctextAdvanced::getAr $win classes classesAr
    set classesAr($class) [list $ref $keywords]
}

#For [ ] { } # etc.
proc ctextAdvanced::addHighlightClassForSpecialChars {win class color chars} {
    set charList [split $chars ""]

    set ref [ctextAdvanced::getAr $win highlightSpecialChars ar]
    foreach char $charList {
	set ar($char) [list $class $color]
    }
    $win tag configure $class

    ctextAdvanced::getAr $win classes classesAr
    set classesAr($class) [list $ref $charList]
}

proc ctextAdvanced::addHighlightClassForRegexp {win class color re} {
    set ref [ctextAdvanced::getAr $win highlightRegexp ar]

    set ar($class) [list $re $color]
    $win tag configure $class

    ctextAdvanced::getAr $win classes classesAr
    set classesAr($class) [list $ref $class]
}

#For things like $blah
proc ctextAdvanced::addHighlightClassWithOnlyCharStart {win class color char} {
    set ref [ctextAdvanced::getAr $win highlightCharStart ar]

    set ar($char) [list $class $color]
    $win tag configure $class

    ctextAdvanced::getAr $win classes classesAr
    set classesAr($class) [list $ref $char]
}

proc ctextAdvanced::deleteHighlightClass {win classToDelete} {
    ctextAdvanced::getAr $win classes classesAr

    if {![info exists classesAr($classToDelete)]} {
	return -code error "$classToDelete doesn't exist"
    }

    foreach {ref keyList} [set classesAr($classToDelete)] {
	upvar #0 $ref refAr
	foreach key $keyList {
	    if {![info exists refAr($key)]} {
		continue
	    }
	    unset refAr($key)
	}
    }
    unset classesAr($classToDelete)
}

proc ctextAdvanced::getHighlightClasses win {
    ctextAdvanced::getAr $win classes classesAr

    array names classesAr
}

proc ctextAdvanced::findNextChar {win index char} {
    set i [$win index "$index + 1 chars"]
    set lineend [$win index "$i lineend"]
    while 1 {
	set ch [$win get $i]
	if {[$win compare $i >= $lineend]} {
	    return ""
	}
	if {$ch == $char} {
	    return $i
	}
	set i [$win index "$i + 1 chars"]
    }
}

proc ctextAdvanced::findNextSpace {win index} {
    set i [$win index $index]
    set lineStart [$win index "$i linestart"]
    set lineEnd [$win index "$i lineend"]
    #Sometimes the lineend fails (I don't know why), so add 1 and try again.
    if {[$win compare $lineEnd == $lineStart]} {
	set lineEnd [$win index "$i + 1 chars lineend"]
    }

    while {1} {
	set ch [$win get $i]

	if {[$win compare $i >= $lineEnd]} {
	    set i $lineEnd
	    break
	}

	if {[string is space $ch]} {
	    break
	}
	set i [$win index "$i + 1 chars"]
    }
    return $i
}

proc ctextAdvanced::findPreviousSpace {win index} {
    set i [$win index $index]
    set lineStart [$win index "$i linestart"]
    while {1} {
	set ch [$win get $i]

	if {[$win compare $i <= $lineStart]} {
	    set i $lineStart
	    break
	}

	if {[string is space $ch]} {
	    break
	}

	set i [$win index "$i - 1 chars"]
    }
    return $i
}

proc ctextAdvanced::clearHighlightClasses {win} {
    #no need to catch, because array unset doesn't complain
    #puts [array exists ::ctextAdvanced::highlight$win]

    ctextAdvanced::getAr $win highlight ar
    array unset ar

    ctextAdvanced::getAr $win highlightSpecialChars ar
    array unset ar

    ctextAdvanced::getAr $win highlightRegexp ar
    array unset ar

    ctextAdvanced::getAr $win highlightCharStart ar
    array unset ar

    ctextAdvanced::getAr $win classes ar
    array unset ar
}

#This is a proc designed to be overwritten by the user.
#It can be used to update a cursor or animation while
#the text is being highlighted.
proc ctextAdvanced::update {} {

}

proc ctextAdvanced::highlight {win start end {afterTriggered 0}} {
    ctextAdvanced::getAr $win config configAr

    if {$afterTriggered} {
	set configAr(highlightAfterId) ""
    }

    if {!$configAr(-highlight)} {
	return
    }

    set si $start
    set twin "$win._t"

    #The number of times the loop has run.
    set numTimesLooped 0
    set numUntilUpdate 600

    ctextAdvanced::getAr $win highlight highlightAr
    ctextAdvanced::getAr $win highlightSpecialChars highlightSpecialCharsAr
    ctextAdvanced::getAr $win highlightRegexp highlightRegexpAr
    ctextAdvanced::getAr $win highlightCharStart highlightCharStartAr

    while 1 {
	set res [$twin search -count length -regexp -- {([^\s\(\{\[\}\]\)\.\t\n\r;\"'\|,]+)} $si $end]
	if {$res == ""} {
	    break
	}

	set wordEnd [$twin index "$res + $length chars"]
	set word [$twin get $res $wordEnd]
	set firstOfWord [string index $word 0]

	if {[info exists highlightAr($word)] == 1} {
	    set wordAttributes [set highlightAr($word)]
	    foreach {tagClass color} $wordAttributes break

	    $twin tag add $tagClass $res $wordEnd
	    if { [llength $color] == 1 } { 
	    	$twin tag configure $tagClass -foreground $color
		} elseif { [expr [llength $color] % 2] == 0 } {
			$twin tag configure $tagClass {*}$color
		}
		
	} elseif {[info exists highlightCharStartAr($firstOfWord)] == 1} {
	    set wordAttributes [set highlightCharStartAr($firstOfWord)]
	    foreach {tagClass color} $wordAttributes break

	    $twin tag add $tagClass $res $wordEnd
	    if { [llength $color] == 1 } { 
	    	$twin tag configure $tagClass -foreground $color
		} elseif { [expr [llength $color] % 2] == 0 } {
			$twin tag configure $tagClass {*}$color
		}
	}
	set si $wordEnd

	incr numTimesLooped
	if {$numTimesLooped >= $numUntilUpdate} {
	    ctextAdvanced::update
	    set numTimesLooped 0
	}
    }

    foreach {ichar tagInfo} [array get highlightSpecialCharsAr] {
	set si $start
	foreach {tagClass color} $tagInfo break

	while 1 {
	    set res [$twin search -- $ichar $si $end]
	    if {"" == $res} {
		break
	    }
	    set wordEnd [$twin index "$res + 1 chars"]

	    $twin tag add $tagClass $res $wordEnd
	    if { [llength $color] == 1 } { 
	    	$twin tag configure $tagClass -foreground $color
		} elseif { [expr [llength $color] % 2] == 0 } {
			$twin tag configure $tagClass {*}$color
		}
	    set si $wordEnd

	    incr numTimesLooped
	    if {$numTimesLooped >= $numUntilUpdate} {
		ctextAdvanced::update
		set numTimesLooped 0
	    }
	}
    }

    foreach {tagClass tagInfo} [array get highlightRegexpAr] {
	set si $start
	foreach {re color} $tagInfo break
	while 1 {
	    set res [$twin search -count length -regexp -- $re $si $end]
	    if {"" == $res} {
		break
	    }

	    set wordEnd [$twin index "$res + $length chars"]
	    $twin tag add $tagClass $res $wordEnd
	    if { [llength $color] == 1 } { 
	    	$twin tag configure $tagClass -foreground $color
		} elseif { [expr [llength $color] % 2] == 0 } {
			$twin tag configure $tagClass {*}$color
		}
	    set si $wordEnd

	    incr numTimesLooped
	    if {$numTimesLooped >= $numUntilUpdate} {
		ctextAdvanced::update
		set numTimesLooped 0
	    }
	}
    }
}

# Stolen from Tcl/Tk wiki: https://wiki.tcl-lang.org/page/line+numbers+in+text+widget
# Thanks Bryan Oakley
proc ctextAdvanced::traceCallback {text canvas font args} {

	ctextAdvanced::getAr $text config configAr
    # only redraw if args are null (meaning we were called by a binding)
    # or called by the trace and the command could potentially change
    # the size of a line.
    set benign {
        mark bbox cget compare count debug dlineinfo
        dump get index mark peer search
    }
    if {[llength $args] == 0 ||
        [lindex $args 0 1] ni $benign} {

        $canvas delete all
        set i [$text index @0,0]
        while true {
            set dline [$text dlineinfo $i]
            if {[llength $dline] == 0} break
            set height [lindex $dline 3]
            set y [lindex $dline 1]
            set cy [expr {$y + int($height/2.0)}]
            set linenum [lindex [split $i .] 0]
            set rect [$canvas create rectangle 0 $y [$canvas cget -width] [expr $y+$height] \
            	-fill [$canvas cget -background] -outline [$canvas cget -background] ]
            set item [$canvas create text 0 $y -anchor nw -width 40 -text $linenum \
            	-fill $configAr(-linemapfg) -font $configAr(-font) \
            	-tags {numbers} -justify right ]
            $canvas bind $item <ButtonPress-1> \
            	[list ctextAdvanced::toggleLinenumber $text $canvas $item $rect $linenum]
            $canvas bind $rect <ButtonPress-1> \
            	[list ctextAdvanced::toggleLinenumber $text $canvas $item $rect $linenum]
            set i [$text index "$i + 1 line"]
        }

    }
}

proc ctextAdvanced::toggleLinenumber {win canvas item rect line} {
	ctextAdvanced::getAr $win config configAr
	
	if {!$configAr(-linemap_markable)} {
	return
    }
	
	set fill [$canvas itemcget $item -fill]
	if { $fill == $configAr(-linemap_select_fg) && \
		[$canvas itemcget $item -font] == $configAr(-linemap_font_select) && \
		[$canvas itemcget $rect -fill] == $configAr(-linemap_select_bg)} {
		$canvas itemconfigure $item -fill $configAr(-linemapfg) \
			-font $configAr(-font)
		$canvas itemconfigure $rect -fill $configAr(-linemapbg) -outline $configAr(-linemapbg)
		
		set type unmarked
	} else {
		$canvas itemconfigure $item -fill $configAr(-linemap_select_fg) \
			-font $configAr(-linemap_font_select)
		$canvas itemconfigure $rect -fill $configAr(-linemap_select_bg) -outline $configAr(-linemap_select_bg)
	
		set type marked
	}
	
	if {[string length $configAr(-linemap_mark_command)]} {
	uplevel #0 [linsert $configAr(-linemap_mark_command) end $win $type $line]
    }
}

proc ctextAdvanced::modified {win value} {
    ctextAdvanced::getAr $win config ar
    set ar(modified) $value
    event generate $win <<Modified>>
    return $value
}
