type LiveClockProps = {
  time: Date
}

export function LiveClock({ time }: LiveClockProps): React.JSX.Element {
  return (
    <time dateTime={time.toISOString()}>
      {time.toLocaleTimeString()}
    </time>
  );
}