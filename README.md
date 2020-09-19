Yucca 🌱
-------

🚧 WIP: This project is just for fun! 🚧

A Mirage Unikernel for your Apollo apps! Yucca provides a unikernel that exposes a git repository using Graphql on a URL for your Apollo client to get data from. 

### Building Locally 

Checkout the repository and get node with `npm` and OCaml with `opam`. Then: 

```
npm install 
npm full
unikernel/yucca
```

This will (a) compile the Reason app in `/client`, (b) bundle everything together with `parcel`, (c) install unikernel dependencies and (d) build the unikernel 🎉! Check the `package.json` file for the full list of commands being run.