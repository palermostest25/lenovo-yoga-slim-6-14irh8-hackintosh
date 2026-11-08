ObjC.import('CoreGraphics');
ObjC.import('Foundation');
var maxD=16, ids=Ref(), cnt=Ref();
$.CGGetActiveDisplayList(maxD, ids, cnt);
var out=[];
var n=cnt[0];
for (var i=0;i<n;i++){
  var d=ids[i];
  var cur=$.CGDisplayCopyDisplayMode(d);
  out.push('Display '+d+' builtin='+$.CGDisplayIsBuiltin(d)+' current='+$.CGDisplayModeGetWidth(cur)+'x'+$.CGDisplayModeGetHeight(cur)+' px='+$.CGDisplayModeGetPixelWidth(cur)+'x'+$.CGDisplayModeGetPixelHeight(cur)+' @'+$.CGDisplayModeGetRefreshRate(cur));
  var opts=$.NSDictionary.dictionaryWithObjectForKey($.NSNumber.numberWithBool(true), $('kCGDisplayShowDuplicateLowResolutionModes'));
  var modes=ObjC.castRefToObject($.CGDisplayCopyAllDisplayModes(d, opts));
  var c=modes.count;
  for (var j=0;j<c;j++){
    var m=modes.objectAtIndex(j);
    var w=$.CGDisplayModeGetWidth(m), h=$.CGDisplayModeGetHeight(m), pw=$.CGDisplayModeGetPixelWidth(m), ph=$.CGDisplayModeGetPixelHeight(m);
    out.push('   '+w+'x'+h+' (pixels '+pw+'x'+ph+(pw>w?' HiDPI':'')+') @'+$.CGDisplayModeGetRefreshRate(m)+' usable='+$.CGDisplayModeIsUsableForDesktopGUI(m));
  }
}
out.join('\n');
