import { INotif } from '../types/interfaces';
import React, { useState, useEffect } from 'react';


interface NotifProps {
    notifyData: INotif;
    onDismiss: () => void;
}

const Notif = ({notifyData, onDismiss}: NotifProps) => {
    const [animationClass, setAnimationClass] = useState('animate__backInRight');

    useEffect(() => {
        const timeoutId = setTimeout(() => {
          setAnimationClass('animate__backOutRight');
        }, 5000);
        return () => {
          clearTimeout(timeoutId);
        };
      }, [notifyData]);
    
      function handleAnimationEnd(e: React.AnimationEvent<HTMLInputElement>) {
        if (e.animationName === 'backOutRight') {
          onDismiss();
        }
      }

    return (
        <div
            id="notif"
            className={`animate__animated ${animationClass}`}
            onAnimationEnd={handleAnimationEnd}
            style={{ borderColor: notifyData.colour }}
        >
            <div id="notif-icon" style={{color: notifyData.colour}}>{notifyData.icon}</div>
            <div id="notif-text">{notifyData.text}</div>
        </div>
    )
}

export default Notif