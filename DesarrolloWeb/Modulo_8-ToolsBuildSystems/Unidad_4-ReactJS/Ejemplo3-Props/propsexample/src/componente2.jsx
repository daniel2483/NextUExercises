import React from 'react';

class Componente2 extends React.Component{
  render(){
    return (
      <div>
        <h2>{this.props.mensajeProps}</h2>
        <h3>{this.props.mensaje3}</h3>
        <div>
          <button onClick={this.props.cambioEstado}>Cambiar Estado con Props</button>
        </div>
      </div>
    )
  }
}

Componente2.defaultProps = {
  mensaje3: 'Props por defecto'
}

export default Componente2;
