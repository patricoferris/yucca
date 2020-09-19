module BlogQuery = [%graphql {|
  query BlogQuery($blog: Key!) {
    branch(name: "data") {
      tree {
        get(key: $blog)
      }
    }
  }
|}];

[@react.component]
let make = (~url) => { 
  let (res, _) = ApolloHooks.useQuery(~variables=BlogQuery.makeVariables(~blog=url, ()), BlogQuery.definition);
  React.useEffect(() => [%bs.raw {|
    document.querySelectorAll('pre code').forEach((block) => {
      hljs.highlightBlock(block);
    })|}]);
  switch(res) {
      | Loading => <p>{React.string("Loading...")}</p>
      | Data(data) =>
        switch(data##branch) {
        | Some(data) => 
          Js.log(data);
          let json = [%bs.raw {| data.tree.get |}];
          Js.log(json);
          let parsed_json = [%bs.raw {| JSON.parse(JSON.parse(json)) |}];
          Js.log(parsed_json);
          let front = [%bs.raw {| parsed_json.frontmatter[0] |}];
          <>
            <h1>{React.string(front##title)}</h1>
            <h4>{React.string(front##updated)}</h4>
            <div dangerouslySetInnerHTML={[%bs.raw {| {__html: parsed_json.html }|}]}></div>
          </>;
        | None => <div>{React.string("No data... yikes!")}</div>;
        }
      | NoData => <p>{React.string("No Data...")}</p>
      | Error(_) => <p>{React.string("Error")}</p>
    }
}