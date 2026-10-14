import modelsTest from './Models.test';
import clientsTest from './Clients.test';
import serviceTests from './Service.test';

// SDK LocalTest runner calls this default suite. Later waves run their own scoped
// .test suites; never import nonexistent future tests or edit this foundation list.
export default function testsuite(): void {
  modelsTest();
  clientsTest();
  serviceTests();
}
