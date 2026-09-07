import { useState } from 'react'
import reactLogo from './assets/react.svg'
import viteLogo from './assets/vite.svg'
import heroImg from './assets/hero.png'
import './App.css'
import gsap from "gsap"
import { useGSAP } from '@gsap/react'


function App() {
  const [count, setCount] = useState(0)

  useGSAP(() => {
    const boxes = gsap.utils.toArray(".box");

    boxes.forEach((box, i) => {
      let x = 0 + 100*i;
      let y = 0 + 100*i;
      let vx = 10 + 5*i;
      let vy = 10 + 5*i;
      const setX = gsap.quickSetter(box, "x", "px");
      const setY = gsap.quickSetter(box, "y", "px");
      const size = 100;

      gsap.set(box, { x, y });

      gsap.ticker.add(() => {
        x += vx;
        y += vy;

        if (x<0 || x>window.innerWidth - size)
        {
          gsap.killTweensOf(box);
          vx *= -1;
        }
        if (y<0 || y>window.innerHeight - size)
        {
          gsap.killTweensOf(box);
          vy *= -1;
        }

        setX(x);
        setY(y);

        
      })
    })
  }, []);

  return (
    <div className="relative w-screen h-screen overflow-hidden">
      <div className="absolute bg-amber-200 w-[100px] h-[100px] box"> </div>
      <div className="absolute bg-amber-200 w-[100px] h-[100px] box"> </div>
    </div>
  )
}

export default App
