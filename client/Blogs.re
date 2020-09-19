module UserQuery = [%graphql {|
  query UserQuery {
    branch(name: "trunk") {
      tree {
        get_tree(key: "blogs") {
          list_contents_recursively {
            key
          }
        }
      }
    }
  }
|}];

[@react.component]
let make = () => { 
  let (branch, _) = ApolloHooks.useQuery(UserQuery.definition);

  <div>{
    switch(branch) {
      | Loading => <p>{React.string("Loading...")}</p>
      | Data(data) =>
        switch(data##branch) {
        | Some(data) =>
          let possible_pages = [%bs.raw {| data.tree.get_tree.list_contents_recursively |}];
          let content = Belt.Array.keepMap(possible_pages, x => { 
            let key = x##key;
            let len = String.length(key);
            if (len > 2) {
              if (String.(sub(key, len - 2, 2) == "md")) {
                Some(x);
              } else {
                None;
              }
            } else {
              None;
            }
          });
          ReasonReact.array(Array.map(x => <div className="link" onClick={_ => ReasonReactRouter.push(x##key)}>{React.string(x##key)}</div>, content));
        | None => <div></div>;
        }
      | NoData => <p>{React.string("No Data...")}</p>
      | Error(_) => <p>{React.string("Error")}</p>
    }
  }</div>;
}