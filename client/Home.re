  
[@react.component]
let make = () => 
  <>
    <h1> {React.string("Patrick Ferris")} </h1>
    <p>{ReasonReact.string("Open-source Software Developer at ")} <a href="https://tarides.com">{ReasonReact.string("Tarides")}</a></p>

    <h3>{React.string("Some Interests:")}</h3>
    <ul>
      <li>{React.string("Open Source Projects: whether its hardware or software I think open source projects are great. They provide a great opportunity for more people to get involved with technology and for more non-profit oriented projects to get off the ground.")}</li>
      <li>{React.string({js| OCaml and MirageOS 🐫 🏝: when I first learnt about functional programming I didn't get it, now it's hard not to use it. MirageOS is a library operating system for building unikernels - they are small, low-power, secure OSes.|js})}</li>
      <li>{React.string({js| RISC-V 🤖: the open source specification for a RISC ISA which enables anybody to build their own processors and extend them in whatever way suits them - there is a big opportunity here for developing highly specialised, secure, low-power processors.|js})}</li>
      <li>{React.string({js| Environmentalism 🌳: it's probably somewhat obvious from the number of times I said "low-power" but the tech industry has a duty to (a) lower its carbon footprint and (b) providing tooling for tackling climate change.|js})}</li>
    </ul>

    <p>{React.string("The blog contains some of the things I find interesting about OCaml, functional programming and more generally computer science.")}</p>
  </>;