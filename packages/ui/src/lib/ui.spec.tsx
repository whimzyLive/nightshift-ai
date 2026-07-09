import { render } from '@testing-library/react';

import NextjsTemplateUi from './ui';

describe('NextjsTemplateUi', () => {
  it('should render successfully', () => {
    const { baseElement } = render(<NextjsTemplateUi />);
    expect(baseElement).toBeTruthy();
  });
});
