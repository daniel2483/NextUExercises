import React from 'react'
import { Link } from 'react-router'

class App extends React.Component{
  render(){
    return(
      <div>
        <ul>
          <li><Link to="/home">Home</Link></li>
          <li><Link to="/usuarios">Usuarios</Link</li>
          <li><Link to="/lenguajes">Lenguajes<Link></li>
        </ul>
        <div>{this.props.children}
        </div>
      </div>
    )
  }
}

export default App;
