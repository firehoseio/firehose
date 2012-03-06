(function() {

  this.module = function(names, fn) {
    var space, _name;
    if (typeof names === 'string') names = names.split('.');
    space = this[_name = names.shift()] || (this[_name] = {});
    space.module || (space.module = this.module);
    if (names.length) {
      return space.module(names, fn);
    } else {
      return fn.call(space);
    }
  };

}).call(this);
