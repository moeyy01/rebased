(window.webpackJsonp=window.webpackJsonp||[]).push([[27],{666:function(t,a,e){"use strict";e.r(a),e.d(a,"default",function(){return L});var o,n,c,i=e(0),s=e(2),r=e(6),u=e(1),d=e(58),p=e.n(d),l=(e(3),e(8)),b=e(13),f=e(4),h=e.n(f),j=e(15),O=e.n(j),v=e(120),m=e(19),w=e(29),I=e(151),g=e(227),y=e(228),M=e(580),C=e(30),L=Object(l.connect)(function(t,a){var e,o=a.params.username,n=(a.withReplies,t.get("me")),c=t.getIn(["accounts"]),s=-1;s=t.getIn(["accounts",-1,"username"],"").toLowerCase()===o.toLowerCase()?null:(e=c.find(function(t){return o.toLowerCase()===t.getIn(["acct"],"").toLowerCase()}))?e.getIn(["id"],null):-1;var i=Object(C.c)(t,s,"following"),r=t.getIn(["relationships",s,"blocked_by"],!1);return{accountId:s,unavailable:n!==s&&r,isAccount:!!t.getIn(["accounts",s]),accountIds:t.getIn(["user_lists","following",s,"items"]),hasMore:!!t.getIn(["user_lists","following",s,"next"]),diffCount:i}})((c=n=function(n){function t(){for(var t,a=arguments.length,e=new Array(a),o=0;o<a;o++)e[o]=arguments[o];return t=n.call.apply(n,[this].concat(e))||this,Object(u.a)(Object(s.a)(t),"handleLoadMore",p()(function(){t.props.accountId&&-1!==t.props.accountId&&t.props.dispatch(Object(m.A)(t.props.accountId))},300,{leading:!0})),t}Object(r.a)(t,n);var a=t.prototype;return a.componentDidMount=function(){var t=this.props,a=t.params.username,e=t.accountId;e&&-1!==e?(this.props.dispatch(Object(m.B)(e)),this.props.dispatch(Object(m.F)(e))):this.props.dispatch(Object(m.C)(a))},a.componentDidUpdate=function(t){var a=this.props,e=a.accountId,o=a.dispatch;e&&-1!==e&&e!==t.accountId&&e&&(o(Object(m.B)(e)),o(Object(m.F)(e)))},a.render=function(){var t=this.props,a=t.accountIds,e=t.hasMore,o=t.isAccount,n=t.diffCount,c=t.accountId,s=t.unavailable;return o||-1===c?-1!==c&&a?s?Object(i.a)(g.a,{},void 0,Object(i.a)("div",{className:"empty-column-indicator"},void 0,Object(i.a)(w.a,{id:"empty_column.account_unavailable",defaultMessage:"Profile unavailable"}))):Object(i.a)(g.a,{},void 0,Object(i.a)(y.a,{scrollKey:"following",hasMore:e,diffCount:n,onLoadMore:this.handleLoadMore,emptyMessage:Object(i.a)(w.a,{id:"account.follows.empty",defaultMessage:"This user doesn't follow anyone yet."})},void 0,a.map(function(t){return Object(i.a)(I.a,{id:t,withNote:!1},t)}))):Object(i.a)(g.a,{},void 0,Object(i.a)(v.a,{})):Object(i.a)(g.a,{},void 0,Object(i.a)(M.a,{}))},t}(b.a),Object(u.a)(n,"propTypes",{params:h.a.object.isRequired,dispatch:h.a.func.isRequired,accountIds:O.a.orderedSet,hasMore:h.a.bool,isAccount:h.a.bool,unavailable:h.a.bool,diffCount:h.a.number}),o=c))||o}}]);
//# sourceMappingURL=following-f3d0ca6ebfbf5da3c20d.chunk.js.map