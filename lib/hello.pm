package hello;
use nginx;
 
sub handler {
  my $r = shift;
  $r->send_http_header("text/html");
  return OK if $r->header_only;
 
  $r->print("hello!\n<br/>");
  $r->rflush;
 
  if (-f $r->filename or -d _) {
    $r->print($r->uri, " exists!\n");
  }
 
  return OK;
}
 
1;
__END__
