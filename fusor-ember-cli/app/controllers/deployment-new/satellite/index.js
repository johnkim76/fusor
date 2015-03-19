import Ember from 'ember';
import SatelliteControllerMixin from "../../../mixins/satellite-controller-mixin";
import EmberValidations from 'ember-validations';

export default Ember.Controller.extend(SatelliteControllerMixin, EmberValidations.Mixin, {

  needs: ['deployment-new', 'deployment-new/satellite'],

  validations: {
    name: {
      presence: true,
    },
  },

  name: Ember.computed.alias("controllers.deployment-new.name"),
  description: Ember.computed.alias("controllers.deployment-new.description"),

  organizationTabRouteName: Ember.computed.alias("controllers.deployment-new/satellite.organizationTabRouteName"),

  disableNextOnDeploymentName: Ember.computed.alias("controllers.deployment-new.disableNextOnDeploymentName"),

});