import { useState } from 'react';
import IntakePanel from './components/IntakePanel.jsx';
import ProductionPlanner from './components/ProductionPlanner.jsx';
import DispatchScheduler from './components/DispatchScheduler.jsx';

const TABS = [
  { id: 'intake', label: 'MH Pro Intake', Component: IntakePanel },
  { id: 'planner', label: 'Production Planner', Component: ProductionPlanner },
  { id: 'dispatch', label: 'Dispatch & Loads', Component: DispatchScheduler },
];

export default function App() {
  const [active, setActive] = useState('intake');
  const { Component } = TABS.find((tab) => tab.id === active);

  return (
    <div className="app">
      <header>
        <h1>Precast Operations Master</h1>
        <nav>
          {TABS.map((tab) => (
            <button
              key={tab.id}
              type="button"
              className={tab.id === active ? 'tab active' : 'tab'}
              onClick={() => setActive(tab.id)}
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </header>
      <main>
        <Component />
      </main>
    </div>
  );
}
