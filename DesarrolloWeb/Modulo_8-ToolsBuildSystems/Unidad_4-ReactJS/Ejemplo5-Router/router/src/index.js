import React from 'react';
//import ReactDOM from 'react-dom';
import { render } from 'react-dom'
import { Router } from 'react-router'
import App from './App.jsx'
import Home from './home.jsx'
import Usuarios from './usuarios.jsx'
import Lenguajes from './lenguajes.jsx'
//import './index.css';
//import App from './App';
//import reportWebVitals from './reportWebVitals';

//ReactDOM.render(
//  <React.StrictMode>
//    <App />
//  </React.StrictMode>,
//  document.getElementById('root')
//);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
//reportWebVitals();

render (
  <Router>
    
  </Router>,
  document.getElementById('app')
)
