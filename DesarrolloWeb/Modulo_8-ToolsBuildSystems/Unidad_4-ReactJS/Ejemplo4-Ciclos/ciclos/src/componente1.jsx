import React from 'react';
import Componente2 from './componente2.jsx'

class Componente1 extends React.Component{
  constructor(){
    super()
    this.state = {
      bienvenido: 'Bienvenido al método constructor'
    }
    console.log('Primera fase: Método Constructor')

  }
  render(){
    console.log('Tercera fase: Método Render, fase principal')
    var valor1 = 500;
    var valor2 = 450;
    var producto = valor1 * valor2;
    return(
      <div>
        <h1>{this.state.bienvenido}</h1>
        <h3>El valor de multiplicación es: {producto}</h3>
      </div>
    )}

  //changeState(){
  //  this.setState({ mensaje: 'Este es un nuevo mensaje...'})
  //}

  componentWillMount(){
    console.log('Bienvenido al metodo componentWillMount');
    console.log('Segunda fase: Método componentWillMount');
  }

  componentDidMount(){
    console.log('Cuarta fase: Método componentDidMount, última fase del ciclo de montaje');
    this.setState({bienvenido:'Bienvenido al método componentDidMount'})
  }

}


export default Componente1;
