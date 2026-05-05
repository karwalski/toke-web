#!/bin/sh
# Generate main.tk with all page routes from build/ output
cat << 'HEADER'
m=website;
i=http:std.http;
i=log:std.log;
i=args:std.args;
i=str:std.str;
i=file:std.file;

f=healthjson():$str{
  <"{\"status\":\"ok\",\"version\":\"0.3.0\",\"service\":\"toke-website\"}"
};

f=main():i64{
  log.openaccess("logs/access.log"; 10000; 30; 0);
  let port=mut.443 as u64;
  let httpmode=mut.false;
  let argc=args.count();
  lp(let i=1;i<(argc as i64);i=i+1){
    let arg=args.get(i as u64);
    if(arg="--http"){httpmode=true};
    if(arg="--port"){
      let nxt=args.get((i+1) as u64);
      let pv=mt str.toint(nxt) {$ok:n n;$err:e 443};
      port=pv as u64;
      i=i+1
    }
  };
  let hj=healthjson();
  http.getstaticmime("/health";hj;"application/json");
  http.getstaticmime("/api/health";hj;"application/json");
  http.getstatic("/api/version";"{\"version\":\"0.3.0\"}");
  http.servedir("/";"build");
HEADER

# Generate a route for each index.html
idx=0
find build -name "index.html" | sort | while read f; do
  route=$(echo "$f" | sed 's|^build||;s|/index.html||')
  [ -z "$route" ] && route="/"
  idx=$((idx+1))
  echo "  let pg${idx}=mt file.read(\"${f}\") {\$ok:v${idx} v${idx};\$err:e${idx} \"\"};"
  echo "  http.getstatic(\"${route}\";pg${idx});"
done

# Generate CSS route
echo '  let pgcss=mt file.read("build/static/css/style.css") {$ok:vcss vcss;$err:ecss ""};'
echo '  http.getstaticmime("/static/css/style.css";pgcss;"text/css");'

cat << 'FOOTER'
  http.vhost("tokelang.dev";"sites/tokelang.dev");
  http.vhost("www.tokelang.dev";"sites/tokelang.dev");
  http.vhost("staging.tokelang.dev";"sites/tokelang.dev");
  http.vhost("loke.tokelang.dev";"sites/loke.tokelang.dev");
  if(httpmode){http.serveworkers(port;2)};
  if(httpmode=false){http.servevhoststls(port;"certs/cert.pem";"certs/key.pem")};
  <0
};
FOOTER
