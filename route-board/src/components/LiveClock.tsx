import { useState, useEffect } from "react";

export function LiveClock(): React.JSX.Element {
  const [time, setTime] = useState<Date>(new Date());

  useEffect(() => {
    const timer: number = window.setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  return (
    <time dateTime={time.toISOString()}>
      {time.toLocaleTimeString()}
    </time>
  );
}