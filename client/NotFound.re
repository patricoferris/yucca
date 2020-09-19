[@react.component]
let make = () => 
  <div>
    <h1> {ReasonReact.string("It was all just a mirage... ")} </h1>
    <p>{React.string("Try going... ")} <Link href="/home" name="Home"/> </p>
  </div>;