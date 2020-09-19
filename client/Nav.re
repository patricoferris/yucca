[@react.component]
let make = () => {

  <nav className="nav container-three-by-one">
    <div className="one-one">
      <h1> <a href="https://twitter.com/patricoferris">{React.string("@patricoferris")}</a></h1>
    </div>
    <div className="nav-buttons">
      <div className="container-three-by-one">
        <div className="one-two"><Link href="/home" name="Home" /></div>
        <div className="one-three"><Link href="/blogs" name="Blogs" /></div>
      </div>
    </div>
  </nav>;
};