[@react.component]
let make = () => {
  let url = ReasonReactRouter.useUrl();
  Js.log(url.path);
  <ReasonApollo.Consumer>
    {(_client) => 
      <div>
        <Nav />
        <div className="content">
        { switch (url.path) {
          | ["blogs"] => <Blogs></Blogs>
          | [""] | ["/"] | ["index.html"] | ["home"]  => <Home />
          | [ "blogs", url ] => <BlogPage url={Js.Json.string("/blogs/" ++ url)}/>
          | _ => <NotFound />
          }}
        </div>
      </div>
    }
  </ReasonApollo.Consumer>
};